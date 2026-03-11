---
name: fix-and-learn
description: Fix unresolved PR review comments and feed the resulting learnings back into the coderabbit review skill.
---

# Fix PR Comments & Learn

PRの未解決レビューコメントを修正し、得られた知見を coderabbit-review スキルに蓄積する。

対象: $ARGUMENTS (省略時は現在のブランチのPR)

## 概要

1. 現在のブランチに紐づくPRの未解決コメントを取得
2. 各コメントを修正（不明瞭な場合はユーザーに質問）
3. lint / type-check を通してコミット & プッシュ
4. 今回の指摘から得た新しいレビュー観点を coderabbit-review スキルに追記
5. claude-dotfiles リポジトリにコミット & プッシュ

## Phase 1: 未解決コメントの取得

> **注意:** `gh pr view --json reviewThreads` は存在しないフィールドでエラーになる。
> 行コメント（レビュースレッド）の取得には **GraphQL API** を使う必要がある。

### Step 1-1: PR情報の取得

```bash
# 現在のブランチに紐づくPRの番号・タイトル・URLを取得
gh pr view --json number,title,url
```

エラーが出た場合（PRが存在しない等）はユーザーに報告して終了。

### Step 1-2: リポジトリのowner/nameを取得

```bash
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
PR_NUM=$(gh pr view --json number --jq '.number')
```

### Step 1-3: GraphQL APIで未解決レビュースレッドを取得

```bash
QUERY="query { repository(owner: \"${OWNER}\", name: \"${REPO}\") { pullRequest(number: ${PR_NUM}) { reviewThreads(first: 100) { nodes { id isResolved isOutdated path line comments(first: 10) { nodes { author { login } body createdAt } } } } } } }"

gh api graphql -f query="$QUERY" \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
```

**よくある失敗パターンと対処:**
- `reviewThreads` フィールドがないエラー → `gh pr view` ではなく上記の GraphQL を使う
- 認証エラー → `gh auth status` で確認
- jq パースエラー → `--jq` を外して生JSONを確認し、構造を目視チェック

### Step 1-4: 各スレッドの情報を整形して表示

```bash
gh api graphql -f query="$QUERY" \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved == false)
    | {
        path,
        line,
        author: .comments.nodes[0].author.login,
        body: .comments.nodes[0].body
      }'
```

- 結果が空なら「未解決コメントはありません」と報告して終了
- コメントがあれば件数とファイル一覧をユーザーに提示してから修正に入る

## Phase 2: コメントの修正

各コメントについて:

1. **コメント内容を分析**
   - 何を求められているか（修正 / 質問への回答 / 設計判断）を判別
   - 対象ファイル・シンボルを特定

2. **不明瞭な場合はユーザーに質問**
   - コメントの意図が読み取れない場合、AskUserQuestion で確認
   - 複数の解釈がありえる場合、選択肢を提示

3. **修正を実施**
   - 対象コードを読み、最小限の変更で指摘に対応
   - CLAUDE.md のコーディング規約・アーキテクチャルールに準拠
   - 関連する箇所（同じパターンの他のファイル）も合わせて修正

4. **TodoWrite で進捗管理**
   - 全コメントをTodoに登録し、1件ずつ in_progress → completed で追跡

## Phase 3: 品質チェック & コミット

1. **プロジェクトのlint / type-check を実行**
   - CLAUDE.md に記載のコマンドを使用（バックエンド: ruff, フロントエンド: eslint + vue-tsc 等）
   - エラーがあれば修正してから次へ

2. **コミット & プッシュ**
   - 変更内容を具体的に記述したコミットメッセージ（日本語、conventional commits prefix）
   - 「レビュー対応」等の曖昧なメッセージは禁止 → 何をしたかを書く
   - pre-commit hook が通ることを確認
   - プッシュ

## Phase 4: coderabbit-review スキルへの知見追記

### 4-1. claude-dotfiles リポジトリの準備

```bash
# /tmp にクローン済みか確認、なければクローン
if [ -d /tmp/claude-dotfiles-tmp ]; then
  git -C /tmp/claude-dotfiles-tmp pull
else
  gh repo clone fairy-pitta/claude-dotfiles /tmp/claude-dotfiles-tmp
fi
```

### 4-2. 新しいレビュー観点の抽出

今回修正したコメント群から、coderabbit-review スキルにまだない観点を特定:

- 既存のセクション番号を確認（`### N. タイトル` 形式）
- 重複する観点はスキップ
- 新しい観点のみ追記

### 4-3. SKILL.md への追記フォーマット

**Review Focus Areas セクション**に追加（`## Review Process` の直前）:

```markdown
### N. [観点タイトル]

[どのようなコードパターンをチェックすべきかの説明]

**Example comment:**
` ` `
_[カテゴリ]_ | _[重要度]_

**[タイトル]**

[説明]

<details>
<summary>[修正案ラベル]</summary>

` ` `diff
[before/after diff]
` ` `
</details>
` ` `
```

**Red Flags セクション**にも対応する項目を追加。

### 4-4. コミット & プッシュ

```bash
cd /tmp/claude-dotfiles-tmp
git add skills/coderabbit-review/SKILL.md
git commit -m "feat: coderabbit-review skillに[観点の要約]を追加"
git push
```

ローカルにも同期:
```bash
cp /tmp/claude-dotfiles-tmp/skills/coderabbit-review/SKILL.md \
   ~/.claude/commands/coderabbit-review/SKILL.md
```

## Phase 5: 完了報告

修正結果のサマリーをユーザーに提示:

```markdown
## 修正完了

**PR:** #[number] ([url])
**コミット:** [hash]

### 修正内容
1. [コメント1の要約] → [何をしたか]
2. [コメント2の要約] → [何をしたか]
...

### coderabbit-review スキル更新
- Section N: [新しい観点1]
- Section M: [新しい観点2]
- Red Flags: [追加項目]
```

## 重要なルール

- **CLAUDE.md のルールを厳守**: アーキテクチャ、コーディング規約、命名規則
- **最小限の変更**: 指摘された箇所だけ直す。周辺のリファクタリングは行わない
- **不明点は聞く**: 推測で修正せず、ユーザーに確認する
- **具体的なコミットメッセージ**: 変更内容が分かるように日本語で書く
- **スキル追記は重複排除**: 既に coderabbit-review に存在する観点は追加しない
- **新観点がない場合はスキップ**: Phase 4 で追記すべき新しい観点がなければスキル更新は省略
