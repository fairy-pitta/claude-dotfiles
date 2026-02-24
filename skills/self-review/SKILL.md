---
name: self-review
description: sora-review → 修正 → backend/frontend-coderabbit → 修正 → frontend-architecture → 修正 の順でスキルと修正を交互に実行し、全スキルで指摘ゼロになるまでループ。各ステップ後にauto-compact。
---

# Self Review Orchestrator

スキルを1つ実行するたびに修正を挟み、**全スキルで指摘ゼロ**になるまでサイクルを繰り返す。

**Announce at start:** "self-review を開始します。スキルと修正を交互に回して全指摘ゼロを目指します。"

---

## コンテキスト管理（最優先ルール）

**各ステップの終わりに必ずコンテキスト使用率を確認し、80% 以上なら即 `/compact` する。**

- compact 後もループは継続する
- compact のタイミング: 修正・テスト・コミットの各ブロック完了後

---

## セットアップ

### 変更ファイルの確認とスキルキューの決定

```bash
git diff --name-only origin/dev...HEAD
```

| 変更ファイル | 実行するスキルキュー（順番通り） |
|---|---|
| `backend/` のみ | sora-review → backend-coderabbit |
| `frontend/` のみ | sora-review → frontend-coderabbit → frontend-architecture |
| 両方 | sora-review → backend-coderabbit + frontend-coderabbit → frontend-architecture |

変更ファイルが0件の場合は「レビュー対象の変更がありません」と報告して終了。

---

## メインループ

以下の **スキルキュー全体で指摘ゼロ** になるまでラウンドを繰り返す。

```
=== Self Review Round <N> ===
```

ラウンド内の各スキルは **レビュー → 修正 → テスト → コミット → compact確認** のセットで順番に処理する。

---

### [STEP A] sora-review

#### A-1. sora-review を適用

sora-review スキルのロジックを適用してレビューを実施する。

- カジュアル・直接的なスタイルで指摘を列挙する
- 指摘件数を記録する

```
sora-review: <N>件
```

指摘が0件なら `sora-review: ✅ 指摘なし` として **STEP B へ進む**（修正・コミットはスキップ）。

#### A-2. 修正

優先度順に修正を実施する:
1. 🔴 Critical / 【必須修正】
2. 🟠 Major / 【要改善】
3. 🟡 Minor
4. 🔵 Trivial / nits

修正時はコードをRead toolで読んでから変更すること。指摘を機械的に適用しない。

#### A-3. テスト実行（必須）

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

テストが失敗した場合はコミットせず修正して再実行する。

#### A-4. コミット

```bash
git add .
git commit -m "fix: <sora-reviewの指摘に基づく具体的な修正内容>"
```

禁止: `fix: sora-reviewの指摘を反映` / `fix: レビュー対応` 等の抽象的表現。
複数テーマにまたがる場合はコミットを分割する。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP B へ

---

### [STEP B] backend-coderabbit / frontend-coderabbit

#### B-1. coderabbit を適用

変更ファイルのパスに応じてスキルを選択して適用する:

- `backend/` のみ → backend-coderabbit の11観点を適用
- `frontend/` のみ → frontend-coderabbit の11観点を適用
- 両方 → backend-coderabbit を `backend/` ファイルに、frontend-coderabbit を `frontend/` ファイルに同時適用

```
backend-coderabbit:  <N>件
frontend-coderabbit: <N>件
```

両方ゼロなら `✅ 指摘なし` として **STEP C へ進む**。

#### B-2. 修正

A-2 と同様に優先度順で修正する。

#### B-3. テスト実行（必須）

A-3 と同じコマンドで全テストを実行する。

#### B-4. コミット

```bash
git add .
git commit -m "fix: <coderabbitの指摘に基づく具体的な修正内容>"
```

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP C へ

---

### [STEP C] frontend-architecture（frontend/ がある場合のみ）

backend のみの場合はこの STEP をスキップして **ラウンドサマリーへ**。

#### C-1. frontend-architecture を適用

frontend-architecture スキルのロジックを適用して CODING_STANDARDS.md の全ルールをチェックする。

```
frontend-architecture: <N>件
```

0件なら `✅ 指摘なし` として修正・コミットをスキップ。

#### C-2. 修正

A-2 と同様に優先度順で修正する。

#### C-3. テスト実行（必須）

A-3 と同じコマンドで全テストを実行する。

#### C-4. コミット

```bash
git add .
git commit -m "fix: <frontend-architectureの指摘に基づく具体的な修正内容>"
```

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → ラウンドサマリーへ

---

### ラウンドサマリー

```
=== Round <N> Summary ===
[STEP A] sora-review:           <N>件 / ✅ 指摘なし
[STEP B] backend-coderabbit:    <N>件 / ✅ 指摘なし  （該当する場合）
[STEP B] frontend-coderabbit:   <N>件 / ✅ 指摘なし  （該当する場合）
[STEP C] frontend-architecture: <N>件 / ✅ 指摘なし  （該当する場合）
```

**全ステップが ✅ 指摘なし → ループ終了（完了レポートへ）**
**1件以上の指摘あり → Round <N+1> へ戻る**

---

## 完了レポート

```
=== Self Review Complete ===

総ラウンド数: <N>
最終状態:
  [STEP A] sora-review:           ✅ 指摘なし
  [STEP B] backend-coderabbit:    ✅ 指摘なし  （該当する場合）
  [STEP B] frontend-coderabbit:   ✅ 指摘なし  （該当する場合）
  [STEP C] frontend-architecture: ✅ 指摘なし  （該当する場合）

全スキルで指摘なしを確認しました。コードをプッシュしてください。
```

---

## Red Flags - Never Do This

- **コンテキスト80%超えのまま `/compact` せずに次ステップへ進まない**
- **テストが失敗したままコミットしない**
- **スキルのチェックリストを実際に適用せずに「指摘なし」と判定しない**
- **`fix: レビュー対応` 等の抽象的なコミットメッセージを使わない**
- **STEP A → B → C の順番を変えない**
- **1ステップでも指摘があればラウンドを最初から回し直す**
