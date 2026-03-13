---
name: iterate-pr
description: PRの未解決コメントを取得し、妥当性を確認。妥当でないものはPRにコメントで返信、妥当なものはplan modeで修正。全コメントに必ず対応（無視ゼロ）。
---

# Iterate PR

PRの未解決レビューコメントを全件取得し、**妥当性を判断してから対応**するスキル。

**鉄則: どんな些細なコメントでも「無視」はしない。修正・Issue作成・返信のいずれかで必ず対応する。**

**Announce at start:** "iterate-pr を開始します。未解決コメントの妥当性を確認して全件対応します。"

**コンテキスト管理:** 各ステップ開始前に80%超えなら `/compact` を実行。

---

## Step 1: Worktree作成

```bash
BRANCH=${ARGUMENTS:-$(git branch --show-current)}
```

Skill tool で `/create-worktree $BRANCH` を呼び出し、worktree に移動。以降の全作業はこの worktree 内で行う。

---

## Step 2: 未解決コメント取得・分類・妥当性判断

### 2-1. GraphQL で未解決スレッドを全件取得

`references/graphql-query.md` のクエリを実行。0件なら報告して終了。

### 2-2. スレッドの分類

| 種別 | 条件 | 処理 |
|------|------|------|
| **既存返信あり** (`comment_count >= 2`) | 最後が承認・了解 | resolve して完了 |
| | 最後が追加指摘 | 妥当性判断へ |
| | 最後がIssue提案 | Issue作成 → リンク返信 → resolve |
| **新規** (`comment_count == 1`) | — | 妥当性判断へ |

迷ったら「追加指摘」として妥当性判断に回す。

### 2-3. 妥当性判断

各コメントについて **対象コードを Read tool で読み**、CLAUDE.md / CODING_STANDARDS.md と照合して判定:

| 判定 | 基準 | 対応 |
|------|------|------|
| **妥当** | バグ・ルール違反・型安全性・命名不備 | 修正する |
| **妥当だがスコープ外** | PR変更範囲外への指摘 | ファイル内完結 → 修正 / 大規模 → Issue作成 |
| **妥当でない** | 事実と異なる・ルールと矛盾・意図的設計 | 返信する |

**「スコープ外なので対応しません」で終わるのは禁止。**

---

## Step 3: ユーザー確認 → Plan Mode

### 3-1. 妥当でないコメントを提示

```
| # | ファイル | 行 | 投稿者 | コメント概要 | 妥当でない理由 |
|---|---------|-----|--------|------------|--------------|
```

### 3-2. `.claude/pr-context.md` に書き出す

**テンプレート:** `references/pr-context-template.md`

`レビュー観点候補` は「なぜセルフレビューで見落としたか」「次回どう検出するか」を考えて書く。

### 3-3. Plan Mode で修正計画を提示

**テンプレート:** `references/plan-template.md`

**Plan mode を終了し、ユーザーの承認を得てから実装を開始する。承認前に一切コードを変更しない。**

---

## Step 4: 修正の実装

Plan に従いコードを修正 → テスト通過を確認 → `/commit-push` でコミット＆プッシュ。

---

## Step 5: Post-Fix（3つの Agent を並列実行）

修正・コミット完了後、以下の3つの Agent を **並列で** 起動する。

`.claude/pr-context.md` を各 Agent のプロンプトに含めること（Agent は親のコンテキストを持たないため）。

### Agent A: 修正コメントへの返信

**プロンプトに含める情報:** Owner/Repo、修正した各 comment_id、対応するコミットハッシュ

```
pr-context.md の「妥当なコメント（修正対象）」セクションを読み、
各 comment_id に対して以下を実行:

gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  --method POST --field body="Fixed in {commit_hash}"
```

### Agent B: 妥当でないコメントへの返信

**プロンプトに含める情報:** Owner/Repo、各 comment_id、返信文案

```
pr-context.md の「妥当でないコメント（返信対象）」セクションを読み、
各 comment_id に対して返信文案の内容で返信:

gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  --method POST --field body="{返信文案}"
```

### Agent C: レビュースキルへの観点追加

**プロンプトに含める情報:** PR番号、各修正の「レビュー観点候補」「対象スキル」

```
pr-context.md の各修正コメントの「レビュー観点候補」を読み、
対象スキルファイルに追記:

- backend/ の指摘 → ~/claude-dotfiles/skills/backend-coderabbit/SKILL.md
- frontend/ の指摘 → ~/claude-dotfiles/skills/frontend-coderabbit/SKILL.md

フォーマット:
  - **<観点名>** [新観点 from PR#<number>] - <チェック内容>。<理由>。<対策>。

既存セクションに収まらない場合は最も近いセクションの末尾に追記。
追記後:
  cd ~/claude-dotfiles && git add skills/ && git commit -m "feat: PR#<number>の指摘からレビュースキルに観点を追加" && git push
```

### 全 Agent 完了後

```bash
rm -f .claude/pr-context.md
```

---

## 完了レポート

```
=== Iterate PR Complete ===

未解決コメント総数: <N>件

対応結果:
  修正:       <N>件（うちスコープ外修正: <N>件）
  Issue作成:  <N>件
  返信:       <N>件（妥当でない旨）
  resolve:    <N>件（承認済みスレッド）
  観点追加:   <N>件（backend: N / frontend: N）

コミット一覧:
  - <hash>: <message>
  - (claude-dotfiles) <hash>: <message>
```

---

## Red Flags

- コメントを読まずに妥当性を判断しない — 必ず対象コードを Read tool で読んでから
- 「対応不要」「スキップ」「スコープ外なので無視」で片付けない — 全件、修正・Issue作成・返信のいずれか
- 既存返信ありスレッドの会話の流れを無視しない — スレッド全体を読んでから判断
- 承認済みスレッドを放置しない — 速やかに resolve
- 「PRレビュー対応」等の抽象的なコミットメッセージを使わない
- テストが失敗したままコミットしない
- 妥当でないと判断した場合、ユーザー確認なしにPRへ返信しない — Step 3 で必ず確認
- Plan Mode に入る前に pr-context.md を書き出さない — Agent のデータソースとして必須
