---
name: self-review
description: sora-review → 修正 → backend/frontend-coderabbit → 修正 → frontend-architecture → 修正 → codex review CLI → 修正 → coderabbit review CLI → 修正 の順でスキルと修正を交互に実行し、全スキルで指摘ゼロになるまでループ。各ステップ後にauto-compact。
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

| 変更ファイル     | 実行するステップ                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `backend/` のみ  | sora-review → backend-coderabbit → codex review CLI → coderabbit review CLI                                               |
| `frontend/` のみ | sora-review → frontend-coderabbit → frontend-architecture → codex review CLI → coderabbit review CLI                      |
| 両方             | sora-review → backend-coderabbit + frontend-coderabbit → frontend-architecture → codex review CLI → coderabbit review CLI |

変更ファイルが0件の場合は「レビュー対象の変更がありません」と報告して終了。

### STEP D/E 用の変数準備

```bash
CLAUDE_MD="/Users/wao_singapore/forval-crossgear/CLAUDE.md"
SKILLS_DIR="$HOME/.claude/skills"

# STEP D用: sora スタイルプロンプト
SORA_PROMPT=$(mktemp /tmp/self-review-sora.XXXXXX)
echo "# Project Rules (CLAUDE.md)" > "$SORA_PROMPT"
cat "$CLAUDE_MD" >> "$SORA_PROMPT"
echo -e "\n---\n" >> "$SORA_PROMPT"
cat "$SKILLS_DIR/sora-review/SKILL.md" >> "$SORA_PROMPT"

# STEP E用: coderabbit.yaml があれば渡す
CODERABBIT_YAML="/Users/wao_singapore/forval-crossgear/coderabbit.yaml"
CR_YAML_ARG=""
[ -f "$CODERABBIT_YAML" ] && CR_YAML_ARG="-c $CODERABBIT_YAML"
```

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
```

テストが失敗した場合はコミットせず修正して再実行する。

#### A-4. コミット

`/commit-push` スキルを使用してコミット＆プッシュする。

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

`/commit-push` スキルを使用してコミット＆プッシュする。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP C へ

---

### [STEP C] frontend-architecture（frontend/ がある場合のみ）

backend のみの場合はこの STEP をスキップして **STEP D へ**。

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

`/commit-push` スキルを使用してコミット＆プッシュする。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP D へ

---

### [STEP D] codex review CLI（常に実行）

`codex review` CLI を使い、Claude 系スキルとは異なる視点でコードレビューを実施する。

#### D-1. codex review 実行

```bash
codex review --base dev - < "$SORA_PROMPT"
```

出力を読んで指摘事項を抽出・件数を記録:

```
codex review: <N>件
```

0件なら `✅ 指摘なし` として修正・コミットをスキップ。

#### D-2. 指摘の妥当性フィルタ

Codex の指摘は CLAUDE.md / CODING_STANDARDS.md のルールと照合し、**プロジェクトルールに反する指摘は除外**する。
除外した場合はその理由を記録する。

```
codex review: <N>件（うち妥当: <M>件、除外: <K>件）
```

妥当な指摘が0件なら `✅ 指摘なし` として修正・コミットをスキップ。

#### D-3. 修正

A-2 と同様に優先度順で修正する。

#### D-4. テスト実行（必須）

A-3 と同じコマンドで全テストを実行する。

#### D-5. コミット

`/commit-push` スキルを使用してコミット＆プッシュする。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP E へ

---

### [STEP E] coderabbit review CLI（常に実行）

`coderabbit review --plain` CLI を使い、CodeRabbit AI によるコードレビューを受ける。

#### E-1. coderabbit review 実行

```bash
coderabbit review --plain --base dev \
  -c "$CLAUDE_MD" \
  $CR_YAML_ARG \
  -c "$SKILLS_DIR/references/review-format.md" \
  -c "$SKILLS_DIR/references/review-process.md"
```

出力を読んで指摘事項を抽出・件数を記録:

```
coderabbit review: <N>件
```

0件なら `✅ 指摘なし` として修正・コミットをスキップ。

#### E-2. 修正

A-2 と同様に優先度順で修正する。

#### E-3. テスト実行（必須）

A-3 と同じコマンドで全テストを実行する。

#### E-4. コミット

`/commit-push` スキルを使用してコミット＆プッシュする。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → ラウンドサマリーへ

---

### ラウンドサマリー

```
=== Round <N> Summary ===
[STEP A] sora-review:           <N>件 / ✅ 指摘なし
[STEP B] backend-coderabbit:    <N>件 / ✅ 指摘なし  （該当する場合）
[STEP B] frontend-coderabbit:   <N>件 / ✅ 指摘なし  （該当する場合）
[STEP C] frontend-architecture: <N>件 / ✅ 指摘なし  （該当する場合）
[STEP D] codex review:          <N>件 / ✅ 指摘なし
[STEP E] coderabbit review:     <N>件 / ✅ 指摘なし
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
  [STEP D] codex review:          ✅ 指摘なし
  [STEP E] coderabbit review:     ✅ 指摘なし

# プロンプトファイルのクリーンアップ
rm -f "$SORA_PROMPT"

全スキルで指摘なしを確認しました。コードをプッシュしてください。
```

---

## Red Flags - Never Do This

- **コンテキスト80%超えのまま `/compact` せずに次ステップへ進まない**
- **テストが失敗したままコミットしない**
- **スキルのチェックリストを実際に適用せずに「指摘なし」と判定しない**
- **`fix: レビュー対応` 等の抽象的なコミットメッセージを使わない**
- **STEP A → B → C → D → E の順番を変えない**
- **1ステップでも指摘があればラウンドを最初から回し直す**
