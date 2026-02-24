---
name: self-review
description: 複数のレビュースキル（sora-review / backend-coderabbit / frontend-coderabbit / frontend-architecture）を順番に回し、全スキルから指摘がなくなるまでループするオーケストレーションスキル。コンテキスト80%でauto-compact。
---

# Self Review Orchestrator

複数のレビュースキルを順番に適用し、**全スキルから指摘ゼロ**になるまで修正→テスト→レビューのサイクルを繰り返す。

**Announce at start:** "self-review を開始します。全スキルで指摘ゼロになるまでループします。"

## コンテキスト管理（最優先ルール）

**コンテキスト使用率が 80% に達したら、次のアクションの前に必ず `/compact` を実行すること。**

コンテキスト使用率の確認方法:
- Claude Code のステータスバーに表示されるトークン使用率を参照
- 各ラウンド開始前に確認し、80% 超えていれば即 `/compact`
- compact 後もループは継続する（状態はこのスキルの指示に従って再構築）

## 使用するスキル一覧

| スキル | 適用条件 |
|---|---|
| **sora-review** | 常に適用（backend/frontend両方） |
| **backend-coderabbit** | `backend/` 配下のファイルが変更に含まれる場合 |
| **frontend-coderabbit** | `frontend/` 配下のファイルが変更に含まれる場合 |
| **frontend-architecture** | `frontend/` 配下のファイルが変更に含まれる場合 |

## セットアップ

### 1. 変更ファイルの確認とスキルセットの決定

```bash
git diff --name-only origin/dev...HEAD
```

- `backend/` を含む → `sora-review` + `backend-coderabbit` を適用キューに追加
- `frontend/` を含む → `sora-review` + `frontend-coderabbit` + `frontend-architecture` を適用キューに追加
- 両方含む → 全4スキルを適用キューに追加

変更ファイルが0件の場合は「レビュー対象の変更がありません」と報告して終了。

### 2. ラウンド管理の初期化

以下の状態を追跡する:
- **ラウンド番号**: 1からスタート
- **各スキルの最終結果**: `指摘あり` / `指摘なし`
- **ループ継続条件**: いずれかのスキルに1件以上の指摘がある間はループ継続

---

## メインループ

以下を「全スキルの指摘がゼロ」になるまで繰り返す。

### ラウンド開始

```
=== Self Review Round <N> ===
対象スキル: [sora-review] [backend-coderabbit / frontend-coderabbit] [frontend-architecture]
```

### Step 1: sora-review の適用

sora-review スキルのロジックを適用してレビューを実施する。

- カジュアル・直接的なスタイルで指摘を列挙
- 指摘件数を記録: `sora-review: <N>件`
- 指摘がない場合: `sora-review: ✅ 指摘なし`

### Step 2: backend-coderabbit / frontend-coderabbit の適用

変更ファイルのパスに応じて適用するスキルを選択:

- `backend/` のみ → backend-coderabbit の11観点を適用
- `frontend/` のみ → frontend-coderabbit の11観点を適用
- 両方 → backend-coderabbit を backend/ ファイルに、frontend-coderabbit を frontend/ ファイルに適用

各スキルの観点に従って指摘を列挙し、件数を記録する。

### Step 3: frontend-architecture の適用（frontend/ がある場合のみ）

frontend-architecture スキルのロジックを適用して CODING_STANDARDS.md の全ルールをチェックする。

- 違反件数を記録: `frontend-architecture: <N>件`
- 違反がない場合: `frontend-architecture: ✅ 指摘なし`

### Step 4: ラウンド結果のサマリー表示

```
=== Round <N> Summary ===
sora-review:           <N>件 / ✅ 指摘なし
backend-coderabbit:    <N>件 / ✅ 指摘なし  （該当する場合）
frontend-coderabbit:   <N>件 / ✅ 指摘なし  （該当する場合）
frontend-architecture: <N>件 / ✅ 指摘なし  （該当する場合）

合計指摘: <N>件
```

**全スキルが指摘なしの場合 → ループ終了（Step 8へ）**
**1件以上の指摘がある場合 → Step 5へ**

### Step 5: 指摘の修正

全スキルの指摘を優先度順にまとめて修正を実施する。

優先度:
1. 🔴 Critical / 【必須修正】
2. 🟠 Major / 【要改善】
3. 🟡 Minor
4. 🔵 Trivial / nits

**重要:** 修正時はコードを読んでから変更すること。指摘内容を機械的に適用せず、コンテキストを理解した上で修正する。

### Step 6: テストの実行（必須）

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

**テストが失敗した場合はコミットせず、失敗を修正してから再実行すること。**

### Step 7: コミット

テスト全通過後、修正内容をコミットする。

- コミットメッセージは**何を修正したかが具体的にわかる**内容にする
- 禁止: `fix: レビュー対応`、`fix: 指摘を反映` 等の抽象的表現
- 複数テーマにまたがる場合はコミットを分割する

```bash
git add .
git commit -m "fix: <具体的な修正内容>"
```

**→ コンテキスト使用率を確認。80% 以上なら `/compact` してから次のラウンドへ。**

**→ Round <N+1> へ戻る**

---

## ループ終了条件

全スキルのラウンド結果が全て「✅ 指摘なし」になったらループを終了する。

### Step 8: 完了レポート

```
=== Self Review Complete ===

総ラウンド数: <N>
最終状態:
  sora-review:           ✅ 指摘なし
  backend-coderabbit:    ✅ 指摘なし  （該当する場合）
  frontend-coderabbit:   ✅ 指摘なし  （該当する場合）
  frontend-architecture: ✅ 指摘なし  （該当する場合）

全スキルで指摘なしを確認しました。コードをプッシュしてください。
```

---

## Red Flags - Never Do This

- **コンテキスト80%を超えたまま `/compact` せずにループを継続しない**
- **テストが失敗したままコミットしない**
- **指摘を確認せずに「指摘なし」と判定しない** — 各スキルのチェックリストを実際に適用すること
- **「PRレビュー指摘を反映」等の抽象的なコミットメッセージを使わない**
- **全スキルを回さずに途中でループを抜けない** — 1スキルでも指摘がある限りループを継続する
