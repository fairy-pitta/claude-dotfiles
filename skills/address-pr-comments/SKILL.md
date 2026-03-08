---
name: address-pr-comments
description: PRの未解決コメントを取得し、妥当性を確認。妥当でないものはPRにコメントで返信、妥当なものはplan modeで修正。全コメントに必ず対応（無視ゼロ）。
---

# Address PR Comments

PRの未解決レビューコメントを全件取得し、**妥当性を判断してから対応**するスキル。

**鉄則: どんな些細なコメントでも「無視」はしない。妥当でなければPRにコメントで返信、妥当であれば修正する。必ずどちらかの対応を取る。**

**Announce at start:** "address-pr-comments を開始します。未解決コメントの妥当性を確認して全件対応します。"

**コンテキスト管理（全ステップ共通・必須）:** **各ステップの開始前**にコンテキスト使用率を確認し、**80%を超えていたら `/compact` を実行してからステップを継続すること。** 例外なく全ステップで適用する。

---

## Step 0: Worktreeの作成と移動

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

```bash
# 現在のブランチ名を取得（引数がなければ現在ブランチ）
BRANCH=${ARGUMENTS:-$(git branch --show-current)}

# worktreeを作成して移動
/create-worktree $BRANCH
cd .git-worktrees/$(echo "$BRANCH" | tr '/' '-')
pwd  # 作業ディレクトリを確認
```

**以降の全作業はこのworktree内で行う。** `pwd` で場所を確認してから作業すること。

---

## Step 1: 未解決コメントを全件取得

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

`gh pr view --json reviewThreads` はデフォルトで**最初の20件しか返さない**。GraphQL + `--paginate` で全件取得すること。

```bash
# PR番号とリポジトリ情報を取得
PR_NUMBER=$(gh pr view --json number --jq '.number')
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

# GraphQLページネーションで全スレッドを取得（100件/ページ × 複数ページ）
gh api graphql --paginate \
  -f owner="$OWNER" \
  -f repo="$REPO" \
  -F number="$PR_NUMBER" \
  -f query='
    query($owner: String!, $repo: String!, $number: Int!, $endCursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              isResolved
              path
              line
              comments(first: 20) {
                nodes {
                  databaseId
                  author { login }
                  body
                }
              }
            }
          }
        }
      }
    }
  ' | jq -s '
    [.[].data.repository.pullRequest.reviewThreads.nodes[]]
    | map(select(.isResolved == false))
    | map({
        id: .id,
        path: .path,
        line: .line,
        comment_count: (.comments.nodes | length),
        first_comment: {
          author: .comments.nodes[0].author.login,
          body: .comments.nodes[0].body,
          comment_id: (.comments.nodes[0].databaseId | tostring)
        },
        last_comment: {
          author: .comments.nodes[-1].author.login,
          body: .comments.nodes[-1].body,
          comment_id: (.comments.nodes[-1].databaseId | tostring)
        },
        all_comments: [.comments.nodes[] | {author: .author.login, body: .body, comment_id: (.databaseId | tostring)}]
      })
  '
```

取得後、**総件数を必ず確認**して報告する。未解決コメントが0件なら「未解決コメントはありません」と報告して終了。

---

## Step 1.5: 既存返信ありスレッドの分類

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

`comment_count >= 2` のスレッド（＝過去に返信済み）は、**最後のコメントの内容で対応を分岐する。**

### 分類ルール

| 最後のコメントの内容 | 対応 |
|---|---|
| **承認・了解系**（"OK", "LGTM", "Looks good", "makes sense", "good point", "that works" 等） | → スレッドを **resolve** して完了。修正不要。 |
| **まだ問題あり系**（具体的な修正要求、"still ...", "but ...", 追加の指摘等） | → 新たな指摘として Step 2 の妥当性判断に回す（最後のコメントの内容を踏まえて再調査） |
| **Issue作成提案系**（"should I create an issue?", "consider filing an issue", "track this separately" 等） | → GitHub Issue を自分で作成し、スレッドにIssueリンクを返信して **resolve** |

### resolve の方法

```bash
# GraphQL mutation でスレッドを resolve
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "<thread_id>"}) {
      thread { isResolved }
    }
  }
'
```

### 重要

- **会話の流れを全て読んでから判断する** — 最後のコメントだけでなく、スレッド全体の文脈を把握すること
- 判断に迷う場合は「まだ問題あり」として Step 2 に回す（安全側に倒す）
- resolve したスレッドは Step 2 以降の対象から除外する

---

## Step 2: 各コメントの妥当性を判断

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

コメントごとに以下を実施する:

1. **対象コードを Read tool で読む**（コンテキストを把握してから判断する）
2. **CLAUDE.md のルールと照合する**
3. **妥当かどうかを判定する**

### 妥当と判断する基準

- CLAUDE.md / CODING_STANDARDS.md のルールに違反している
- バグ・ロジックエラーが含まれている
- セキュリティ・型安全性の問題がある
- コードの意図が不明確、命名が不適切
- 修正することでコードが明確に改善される

### スコープ外コメントの対応基準

PRの変更範囲外に対する指摘（スコープ外コメント）は、**「無視」せず以下のルールで対応する:**

- **修正がそのファイル内で完結する場合** → そのまま修正する（スコープ外でも小さい修正はやる）
- **大規模な修正が必要な場合**（複数ファイルにまたがる、設計変更を伴う等） → GitHub Issue を作成し、PRスレッドにIssueリンクを返信する

```bash
# Issue作成例
gh issue create --title "<指摘内容の要約>" --body "PR #<PR_NUMBER> のレビューで指摘された内容。\n\n## 指摘内容\n<コメント本文>\n\n## 対象ファイル\n<path>:<line>"
```

**「スコープ外なので対応しません」とだけ返信して終わるのは禁止。** 必ず修正するかIssueにするかのどちらかで対応すること。

### 妥当でないと判断する基準

- すでにコードが正しく実装されており、指摘内容が事実と異なる
- プロジェクトのルール（CLAUDE.md）に従った実装であり、指摘がルールと矛盾している
- 指摘者の誤解に基づいている（コードを読めば意図が明確）
- 意図的な設計判断であり、変更する理由がない

---

## Step 3: コンテキスト永続化 → ユーザー確認 → Plan Mode

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

### 3-1. 妥当でないコメントをユーザーに提示

```
## 妥当でないと判断したコメント（スレッドに返信予定）

| # | ファイル | 行 | 投稿者 | コメント概要 | 妥当でない理由 |
|---|---------|-----|--------|------------|--------------|
| 1 | `path/to/file.ts` | 42 | @coderabbitai | コメントの要約 | すでに正しく実装済み。CLAUDE.md X.Y節に準拠している |
| 2 | `backend/app/...` | 88 | @coderabbitai | コメントの要約 | プロジェクトルール上意図的な設計。変更不要 |
```

### 3-2. `.claude/pr-context.md` に全コンテキストを書き出す（Plan Mode の前・必須）

> **Plan Mode を抜けるとスキルフローが断絶する。** 断絶しても post-fix ワークフローを実行できるよう、Plan Mode に入る前に全情報をファイルに書き出す。

**テンプレート:** `references/pr-context-template.md` を参照して `.claude/pr-context.md` に書き出す。

**重要:** `レビュー観点候補` フィールドは post-fix ワークフローで使う。指摘内容を単にコピーするのではなく、**「なぜセルフレビューで見落としたか」「次回どうチェックすれば検出できるか」** を考えて書く。

書き出し後、ファイルの存在を確認:
```bash
cat .claude/pr-context.md | head -5
```

### 3-3. Plan Mode で修正計画を提示

pr-context.md の書き出しが完了してから Plan Mode に入る。

**テンプレート:** `references/plan-template.md` を参照して Plan を作成する。

**Plan mode を終了し、ユーザーの承認を得てから実装を開始する。承認前に一切コードを変更しない。**

---

## Step 4: Post-Fix ワークフロー（Stop hook による自動トリガー）

> **このステップはユーザー操作不要。** Plan 実装（コード修正 → テスト → コミット → プッシュ）が完了し
> エージェントが停止しようとすると、Stop hook (`~/.claude/hooks/post-fix-check.sh`) が
> `.claude/pr-context.md` の存在を検知し、自動で Post-Fix ワークフローの実行を指示する。

Stop hook から指示を受けたら:

1. **`.claude/pr-context.md` を Read tool で読み込む**
2. **Task tool サブエージェントで以下を並列実行:**

### Task A+B: PRスレッドへの返信（並列実行可）

Task tool に以下を委譲:
- **修正した各コメント** の comment_id に対して `Fixed in <commit-hash>` を返信
- **妥当でないコメント** の comment_id に対して返信文案の内容を返信

```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  --method POST \
  --field body="<返信内容>"
```

### Task C: レビュースキルへの観点追加

Task tool に以下を委譲:
- 各修正コメントの「レビュー観点候補」フィールドを基に、対応するレビュースキルに追記
- `backend/` → `~/claude-dotfiles/skills/backend-coderabbit/SKILL.md`
- `frontend/` → `~/claude-dotfiles/skills/frontend-coderabbit/SKILL.md`

追記フォーマット:
```
- **<観点名>** `[新観点 from PR#<number>]` - <チェック内容>。<問題の理由>。<対策>。
```

追記後 claude-dotfiles にコミット＆プッシュ。

3. **全て完了したら `.claude/pr-context.md` を削除:**
```bash
rm -f .claude/pr-context.md
```

4. **完了レポートを出力:**
```
=== Address PR Comments Complete ===

未解決コメント総数: <N>件

対応結果:
  ✅ 修正して解決:                <N>件
  🔧 スコープ外だが修正:          <N>件
  📋 スコープ外→Issue作成:        <N>件
  💬 妥当でないと返信:            <N>件
  ✔️  既存返信→承認済みresolve:    <N>件
  🔄 既存返信→再調査して修正:     <N>件
  📋 既存返信→Issue作成+resolve:  <N>件
  📚 レビュースキルに観点追加:    <N>件（backend: N件 / frontend: N件）

スレッド返信:
  🔧 修正コミット通知:            <N>件
  💬 妥当でない旨の返信:          <N>件
  → 未解決コメント全 <N>件に返信完了（漏れゼロ）

コミット一覧（このリポジトリ）:
  - <hash>: <コミットメッセージ>

コミット一覧（claude-dotfiles）:
  - <hash>: feat: PR#<N>の指摘からレビュースキルに観点を追加
```

---

## Red Flags - Never Do This

- **コメントを読まずに妥当性を判断しない** — 必ず対象コードを Read tool で読んでから判断する
- **「対応不要」「スキップ」「スコープ外なので無視」として片付けない** — 全件、修正・Issue作成・返信のいずれかで必ず対応する
- **「PRレビュー対応」等の抽象的なコミットメッセージを使わない**
- **テストが失敗したままコミットしない**
- **妥当でないと判断した場合、ユーザー確認なしにPRへ返信しない** — Step 3 で必ず確認を取る
- **相手が承認済みのスレッドを放置しない** — 承認系の返信が来ていたら速やかに resolve する
- **既に返信済みスレッドの会話の流れを無視しない** — 最後のコメントだけでなくスレッド全体を読んでから判断する
- **Plan Mode に入る前に pr-context.md を書き出さない** — Stop hook のトリガーに必須
- **Stop hook の指示を無視しない** — pr-context.md が存在する限り Post-Fix を実行すること
