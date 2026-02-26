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
              comments(first: 1) {
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
        author: .comments.nodes[0].author.login,
        body: .comments.nodes[0].body,
        comment_id: (.comments.nodes[0].databaseId | tostring)
      })
  '
```

取得後、**総件数を必ず確認**して報告する。未解決コメントが0件なら「未解決コメントはありません」と報告して終了。

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

`.claude/pr-context.md` に以下を書き出す:

```markdown
# PR Comment Resolution Context

## メタ情報
- PR: #<number> (<url>)
- Owner/Repo: <owner>/<repo>
- ブランチ: <branch-name>
- Worktree: <worktree-path>

## 妥当なコメント（修正対象）

### 修正 1: <ファイルパス>:<行番号>
- **投稿者:** @<author>
- **comment_id:** <comment_id>
- **コメント概要:** <概要>
- **修正方針:** <具体的な修正方法>
- **優先度:** 🔴/🟠/🟡/🔵
- **レビュー観点候補:** <この指摘から得られるレビュー観点。セルフレビューで検出できなかった理由と、次回検出するためのチェックポイント>
- **対象スキル:** backend-coderabbit / frontend-coderabbit

### 修正 2: ...

## 妥当でないコメント（返信対象）

### 返信 1: <ファイルパス>:<行番号>
- **投稿者:** @<author>
- **comment_id:** <comment_id>
- **コメント概要:** <概要>
- **妥当でない理由:** <理由>
- **返信文案:** <PRスレッドに投稿する返信内容>

### 返信 2: ...

## Post-Fix ワークフロー（コード修正・コミット完了後に実行）

以下の作業を Task tool サブエージェントで実行すること。
`.claude/pr-context.md` を Read tool で読み、必要な情報を取得してから作業する。

### Task A: PRスレッドに修正コミットハッシュを返信
修正した各コメントの comment_id に対して以下を実行:
  COMMIT_HASH=$(git rev-parse --short HEAD)
  gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
    --method POST \
    --field body="Fixed in ${COMMIT_HASH}"
コミットを分割した場合は、各コメントに対応する正しいハッシュを使うこと。

### Task B: 妥当でないコメントへの返信
各コメントの comment_id に対して、「返信文案」の内容でスレッドに返信:
  gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
    --method POST \
    --field body="<返信文案の内容>"

### Task C: レビュースキルへの観点追加（最重要・スキップ禁止）
修正した内容はセルフレビューを潜り抜けてきた欠点。次回以降 self-review で検出されるよう、
レビュースキルに観点を追記する。

対象スキルファイル:
- backend/ 配下の修正 → ~/claude-dotfiles/skills/backend-coderabbit/SKILL.md
- frontend/ 配下の修正 → ~/claude-dotfiles/skills/frontend-coderabbit/SKILL.md

追記フォーマット:
  - **<観点名>** `[新観点 from PR#<number>]` - <何をチェックするかの説明>。<なぜ問題になるか>。<どうすれば良いか>。

各修正コメントの「レビュー観点候補」フィールドを参考にすること。
既存セクションに収まらない場合は、最も近いセクションの末尾に追記する。
追記後:
  cd ~/claude-dotfiles && git add skills/ && git commit -m "feat: PR#<number>の指摘からレビュースキルに観点を追加" && git push
```

**重要:** `レビュー観点候補` フィールドは post-fix ワークフローで使う。指摘内容を単にコピーするのではなく、**「なぜセルフレビューで見落としたか」「次回どうチェックすれば検出できるか」** を考えて書く。

書き出し後、ファイルの存在を確認:
```bash
cat .claude/pr-context.md | head -5
```

### 3-3. Plan Mode で修正計画を提示

pr-context.md の書き出しが完了してから Plan Mode に入る。

**Plan の内容:**

```
## 修正計画

**作業ブランチ:** `<branch-name>`（worktree: `.git-worktrees/<branch-name>`）

| # | 優先度 | ファイル | 行 | 内容 | 修正方針 |
|---|--------|---------|-----|------|---------|
| 1 | 🔴 | `path/to/file.ts` | 42 | 指摘概要 | 具体的な修正方法 |
| 2 | 🟠 | `backend/app/...` | 88 | 指摘概要 | 具体的な修正方法 |

## 検証・コミット
- ruff check / type-check / pytest 等
- `/commit-push` スキルでコミット＆プッシュ

## Post-Fix（自動実行）
コミット＆プッシュ後、Stop hook が以下を自動実行:
- PRスレッドに修正コミット通知を返信
- 妥当でないコメントに返信
- レビュースキルに観点を追加（claude-dotfiles）
```

優先度順に並べる:
1. 🔴 Critical / セキュリティ・バグ
2. 🟠 Major / アーキテクチャ・型安全性
3. 🟡 Minor / リファクタ
4. 🔵 Trivial / スタイル・Nitpick

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
  💬 妥当でないと返信:            <N>件
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
- **「対応不要」「スキップ」として無視しない** — 全件、修正か返信のどちらかで必ず対応する
- **「PRレビュー対応」等の抽象的なコミットメッセージを使わない**
- **テストが失敗したままコミットしない**
- **妥当でないと判断した場合、ユーザー確認なしにPRへ返信しない** — Step 3 で必ず確認を取る
- **解決済みコメントを自動で resolve しない** — resolve はレビュワーが行うもの
- **Plan Mode に入る前に pr-context.md を書き出さない** — Stop hook のトリガーに必須
- **Stop hook の指示を無視しない** — pr-context.md が存在する限り Post-Fix を実行すること
