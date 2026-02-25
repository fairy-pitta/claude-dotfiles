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

```bash
gh pr view --json number,title,reviewThreads --jq '
  .reviewThreads[]
  | select(.isResolved == false)
  | {
      id: .id,
      path: .path,
      line: .line,
      author: .comments[0].author.login,
      body: .comments[0].body
    }
'
```

未解決コメントが0件なら「未解決コメントはありません」と報告して終了。

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

## Step 3: ユーザー確認（全件まとめて承認を得る）

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

妥当・妥当でない両方の判断結果をまとめてユーザーに提示し、**一度に承認を得る。** Step 4で並列実行するため、ここで全ての承認を完了させる。

### 3-1. 妥当でないコメント（スレッドに返信予定）

```
## 妥当でないと判断したコメント（スレッドに返信予定）

| # | ファイル | 行 | 投稿者 | コメント概要 | 妥当でない理由 |
|---|---------|-----|--------|------------|--------------|
| 1 | `path/to/file.ts` | 42 | @coderabbitai | コメントの要約 | すでに正しく実装済み。CLAUDE.md X.Y節に準拠している |
| 2 | `backend/app/...` | 88 | @coderabbitai | コメントの要約 | プロジェクトルール上意図的な設計。変更不要 |
```

### 3-2. 妥当なコメント（修正計画）

**Plan Modeに入り、修正計画を提示する。** 作業ブランチを冒頭に明記すること。

```
## 修正計画

**作業ブランチ:** `<branch-name>`（worktree: `.git-worktrees/<branch-name>`）

| # | ファイル | 行 | 内容 | 修正方針 |
|---|---------|-----|------|---------|
| 1 | `path/to/file.ts` | 42 | 指摘概要 | 具体的な修正方法 |
| 2 | `backend/app/...` | 88 | 指摘概要 | 具体的な修正方法 |
```

優先度順に並べる:
1. 🔴 Critical / セキュリティ・バグ
2. 🟠 Major / アーキテクチャ・型安全性
3. 🟡 Minor / リファクタ
4. 🔵 Trivial / スタイル・Nitpick

**Plan modeを終了し、ユーザーの承認を得てからStep 4へ進む。承認前に一切コードを変更しない。**

---

## Step 4: 並列実行（Task toolで同時進行）

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

**ユーザー承認後、以下の2トラックをTask toolで並列に実行する。** 1つのメッセージ内で2つのTask tool呼び出しを同時に行うこと。

### Track A: 修正実施 → テスト → コミット → レビュースキル反映

Task toolで以下を1つのエージェントに委譲する:

#### A-1. 修正を実施

承認された修正計画に従い、優先度順に修正する。修正前に必ず対象ファイルを Read tool で読むこと。

#### A-2. テスト実行（必須）

```bash
# Backend（変更がある場合）
cd backend && pytest

# Frontend（変更がある場合）
pnpm -C frontend run type-check
pnpm -C frontend run lint
pnpm -C frontend run test:unit

# e2e / VRT（存在する場合）
pnpm -C frontend run test:e2e:playwright
pnpm -C frontend run test:visual:docker
```

テストが失敗した場合はコミットせず修正してから再実行する。

#### A-3. コミット＆プッシュ

**`/commit-push` スキルを使用すること。**

**禁止表現:** `fix: レビュー対応` / `fix: コメント対応` / `fix: 指摘を反映` 等の抽象的表現。
複数テーマにまたがる場合はコミットを分割する（分割した分だけ `/commit-push` を実行する）。

#### A-4. レビュースキルへの観点追加（最重要）

**このPRで修正した内容は、セルフレビューを潜り抜けてきた欠点。次回以降は `self-review` で自動検出されるよう、対応するレビュースキルに観点として追記する。**

修正したコメントをファイルパスで分類:
- `backend/` 配下の修正 → `~/claude-dotfiles/skills/backend-coderabbit/SKILL.md` に追記
- `frontend/` 配下の修正 → `~/claude-dotfiles/skills/frontend-coderabbit/SKILL.md` に追記

**追記フォーマット:**
```
- **<観点名>** `[新観点 from PR#<PR番号>]` - <何をチェックするかの説明>。<なぜ問題になるか>。<どうすれば良いか>。
```

**例:**
```
- **useEffectの依存配列の漏れ** `[新観点 from PR#466]` - `useEffect`の依存配列に使用している変数が全て含まれているか。
  漏れがあると古い値を参照したまま動作するバグになる。ESLintの`exhaustive-deps`ルールで検出可能。
```

既存のセクションに収まらない場合は、最も近いセクションの末尾に追記する。

```bash
cd ~/claude-dotfiles
```

**`/commit-push` スキルを使用すること。**

コミットメッセージ例: `feat: PR#<PR番号>の指摘からbackend/frontend-coderabbitに観点を追加`

### Track B: 妥当でないコメントへの返信

Task toolで以下を1つのエージェントに委譲する:

各コメントの **スレッドに直接返信** を投稿する。
`in_reply_to` にコメントIDを指定してスレッドに返信すること。

```bash
# CodeRabbitコメントスレッドへの返信（in_reply_to 必須）
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  --method POST \
  --field body="<返信内容>"
```

**返信の書き方:**
- 丁寧かつ明確に、なぜ対応しないかを説明する
- 該当するCLAUDE.mdのルールや実装の意図を示す
- 相手の意図を否定せず、現状のコードが正しい理由を伝える

例:
```
この実装はCLAUDE.md「Result型パターン」のルール（タプルアンパック必須）に従っており、
意図的な設計です。`result, error = usecase.execute()` の形式がプロジェクト規約のため、
現状を維持します。
```

---

## Step 5: 完了レポート

> **コンテキスト確認:** 80%超えなら `/compact` を実行してから続ける。

```
=== Address PR Comments Complete ===

未解決コメント総数: <N>件

対応結果:
  ✅ 修正して解決:                <N>件
  💬 妥当でないと返信:            <N>件
  📚 レビュースキルに観点追加:    <N>件（backend: N件 / frontend: N件）

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
