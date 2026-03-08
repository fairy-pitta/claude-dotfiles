---
name: address-pr-comments
description: PRの未解決コメントを取得し、妥当性を確認。妥当でないものはPRにコメントで返信、妥当なものはplan modeで修正。全コメントに必ず対応（無視ゼロ）。
---

# Address PR Comments

PRの未解決レビューコメントを全件取得し、**妥当性を判断してから対応**するスキル。

**鉄則: どんな些細なコメントでも「無視」はしない。修正・Issue作成・返信のいずれかで必ず対応する。**

**Announce at start:** "address-pr-comments を開始します。未解決コメントの妥当性を確認して全件対応します。"

**コンテキスト管理（全ステップ共通）:** 各ステップ開始前にコンテキスト使用率を確認し、**80%超えなら `/compact` を実行**してから継続。

---

## Step 0: Worktreeの作成と移動

```bash
BRANCH=${ARGUMENTS:-$(git branch --show-current)}
/create-worktree $BRANCH
cd .git-worktrees/$(echo "$BRANCH" | tr '/' '-')
pwd
```

**以降の全作業はこのworktree内で行う。**

---

## Step 1: 未解決コメントを全件取得

`references/graphql-query.md` のクエリを実行し、未解決スレッドを全件取得する。

取得後、**総件数を報告**する。0件なら「未解決コメントはありません」と報告して終了。

---

## Step 2: スレッドの分類

取得したスレッドを以下の2グループに分け、それぞれ異なるロジックで処理する。

### A. 既存返信ありスレッド（`comment_count >= 2`）

過去に返信済みで、相手からさらに返信が来ているスレッド。**スレッド全体の会話を読み**、最後のコメントの内容で分岐する:

| 最後のコメントの趣旨 | 対応 |
|---|---|
| **承認・了解** (OK, LGTM, makes sense 等) | resolve して完了 |
| **追加の指摘・修正要求** | グループ B と同様に妥当性判断へ |
| **Issue作成の提案** | Issue を作成 → リンク返信 → resolve |

判断に迷う場合は「追加の指摘」として妥当性判断に回す（安全側に倒す）。

### B. 新規スレッド（`comment_count == 1`）または追加指摘として回されたスレッド

Step 3 の妥当性判断に進む。

---

## Step 3: 妥当性の判断

各コメントについて以下を実施:

1. **対象コードを Read tool で読む**
2. **CLAUDE.md / CODING_STANDARDS.md のルールと照合する**
3. **以下の基準で判定する**

### 妥当 → 修正する

- ルール違反、バグ、セキュリティ・型安全性の問題
- 命名が不適切、コードの意図が不明確
- 修正により明確に改善される

### 妥当だがスコープ外 → 修正 or Issue

PRの変更範囲外への指摘は**規模で判断**:

- **ファイル内で完結する修正** → そのまま修正する
- **大規模な修正**（複数ファイル横断、設計変更等） → Issue を作成しリンク返信

**「スコープ外なので対応しません」で終わるのは禁止。**

### 妥当でない → 返信する

- コードが正しく実装されており、指摘が事実と異なる
- CLAUDE.md のルールに従った実装であり、指摘がルールと矛盾
- 指摘者の誤解に基づいている
- 意図的な設計判断であり変更理由がない

---

## Step 4: ユーザー確認 → コンテキスト永続化 → Plan Mode

### 4-1. 妥当でないコメントをユーザーに提示

```
| # | ファイル | 行 | 投稿者 | コメント概要 | 妥当でない理由 |
|---|---------|-----|--------|------------|--------------|
```

### 4-2. `.claude/pr-context.md` に書き出す（Plan Mode の前・必須）

**テンプレート:** `references/pr-context-template.md`

**重要:** `レビュー観点候補` は「なぜセルフレビューで見落としたか」「次回どう検出するか」を考えて書く。

### 4-3. Plan Mode で修正計画を提示

**テンプレート:** `references/plan-template.md`

**Plan mode を終了し、ユーザーの承認を得てから実装を開始する。承認前に一切コードを変更しない。**

---

## Step 5: Post-Fix ワークフロー（Stop hook による自動トリガー）

Plan 実装完了後、Stop hook (`~/.claude/hooks/post-fix-check.sh`) が `.claude/pr-context.md` を検知して自動実行を指示する。

### 実行内容（Task tool で並列実行）

**Task A:** 修正コメントに `Fixed in <commit-hash>` を返信
**Task B:** 妥当でないコメントに返信文案の内容を返信
**Task C:** レビュースキルに観点追加

- `backend/` → `~/claude-dotfiles/skills/backend-coderabbit/SKILL.md`
- `frontend/` → `~/claude-dotfiles/skills/frontend-coderabbit/SKILL.md`
- フォーマット: `- **<観点名>** [新観点 from PR#<number>] - <チェック内容>。<理由>。<対策>。`
- 追記後 claude-dotfiles にコミット＆プッシュ

返信・resolve の操作方法は `references/graphql-query.md` の「共通操作」を参照。

### 完了処理

```bash
rm -f .claude/pr-context.md
```

### 完了レポート

```
=== Address PR Comments Complete ===

未解決コメント総数: <N>件

対応結果:
  ✅ 修正:       <N>件（うちスコープ外修正: <N>件）
  📋 Issue作成:  <N>件
  💬 返信:       <N>件（妥当でない旨）
  ✔️  resolve:    <N>件（承認済みスレッド）
  📚 観点追加:   <N>件（backend: N / frontend: N）

コミット一覧:
  - <hash>: <message>
  - (claude-dotfiles) <hash>: <message>
```

---

## Red Flags - Never Do This

- **コメントを読まずに妥当性を判断しない** — 必ず対象コードを Read tool で読んでから
- **「対応不要」「スキップ」「スコープ外なので無視」で片付けない** — 全件、修正・Issue作成・返信のいずれか
- **既存返信ありスレッドの会話の流れを無視しない** — スレッド全体を読んでから判断
- **承認済みスレッドを放置しない** — 速やかに resolve
- **「PRレビュー対応」等の抽象的なコミットメッセージを使わない**
- **テストが失敗したままコミットしない**
- **妥当でないと判断した場合、ユーザー確認なしにPRへ返信しない** — Step 4 で必ず確認
- **Plan Mode に入る前に pr-context.md を書き出さない** — Stop hook のトリガーに必須
- **Stop hook の指示を無視しない** — pr-context.md が存在する限り Post-Fix を実行
