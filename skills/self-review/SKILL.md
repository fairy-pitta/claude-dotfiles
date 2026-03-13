---
name: self-review
description: sora-review → 修正 → backend/frontend-coderabbit(5並列×2) → 修正 → frontend-architecture → 修正 → codex review CLI → 修正 の順でスキルと修正を交互に実行し、全スキルで指摘ゼロになるまでループ。各ステップ後にauto-compact。
---

# Self Review Orchestrator

レビュースキルを**サブエージェント**として起動し、構造化された結果を受け取って修正する。
**全スキルで指摘ゼロ**になるまでサイクルを繰り返す。

**Announce at start:** "self-review を開始します。各レビューをサブエージェントで並列実行し、全指摘ゼロを目指します。"

---

## コンテキスト管理（最優先ルール）

**各ステップの終わりに必ずコンテキスト使用率を確認し、80% 以上なら即 `/compact` する。**

- compact 後もループは継続する
- compact のタイミング: 修正・テスト・コミットの各ブロック完了後
- **サブエージェント活用により、レビュー自体のコンテキスト消費は最小限になる**

---

## セットアップ

### 変更ファイルの確認とスキルキューの決定

```bash
git diff --name-only origin/dev...HEAD
```

| 変更ファイル     | 実行するステップ                                                                |
| ---------------- | ------------------------------------------------------------------------------- |
| `backend/` のみ  | sora-review → backend-coderabbit(5並列) → codex review CLI                      |
| `frontend/` のみ | sora-review → frontend-coderabbit(5並列) → frontend-architecture → codex review CLI |
| 両方             | sora-review → backend(5並列) + frontend(5並列) → frontend-architecture → codex review CLI |

変更ファイルが0件の場合は「レビュー対象の変更がありません」と報告して終了。

### STEP D 用の変数準備

```bash
CLAUDE_MD="/Users/wao_singapore/forval-crossgear/CLAUDE.md"
SKILLS_DIR="$HOME/.claude/skills"

SORA_PROMPT=$(mktemp /tmp/self-review-sora.XXXXXX)
echo "# Project Rules (CLAUDE.md)" > "$SORA_PROMPT"
cat "$CLAUDE_MD" >> "$SORA_PROMPT"
echo -e "\n---\n" >> "$SORA_PROMPT"
PLAN_FILE=".claude/plan.md"
if [ -f "$PLAN_FILE" ]; then
  echo "# Implementation Plan" >> "$SORA_PROMPT"
  cat "$PLAN_FILE" >> "$SORA_PROMPT"
  echo -e "\n---\n" >> "$SORA_PROMPT"
fi
cat "$SKILLS_DIR/sora-review/SKILL.md" >> "$SORA_PROMPT"
```

---

## サブエージェント起動の共通ルール

各レビューステップでは Agent tool を使い、以下の共通プロンプト構造で起動する:

```
あなたはコードレビューのサブエージェントです。以下の手順で実行してください:

1. スキルファイルを読む: Read tool で `<SKILL.md path>` を読み込む
2. references/ 配下のファイルがあれば全て読む
3. CLAUDE.md を読む（プロジェクトルール確認用）
4. 変更ファイルを取得: `git diff --name-only origin/dev...HEAD` （該当パスでフィルタ）
5. 各変更ファイルを Read tool で読む
6. スキルの Checklist に従ってレビューを実施する
7. 結果を Sub-Agent Output Format に従って返す

コードの修正は行わず、検出と報告のみ行うこと。
```

### サブエージェントの出力を受け取った後の共通フロー

1. **Findings を確認**: 「要対応」の件数を数える
2. **0件なら** → `✅ 指摘なし` として次のSTEPへ（修正・コミットはスキップ）
3. **1件以上なら** → 修正 → テスト → コミットの順で処理

---

## メインループ

以下の **スキルキュー全体で指摘ゼロ** になるまでラウンドを繰り返す。

```
=== Self Review Round <N> ===
```

---

### [STEP A] sora-review（サブエージェント）

#### A-1. サブエージェント起動

Agent tool で起動する:

```
description: "sora-review sub-agent"
prompt: |
  あなたはコードレビューのサブエージェントです。以下の手順で実行してください:

  1. スキルファイルを読む: `$HOME/.claude/skills/sora-review/SKILL.md`
  2. `$HOME/.claude/skills/sora-review/references/` 配下のファイルを全て読む
  3. プロジェクトの CLAUDE.md を読む
  4. `git diff --name-only origin/dev...HEAD` で変更ファイルを取得
  5. 各変更ファイルを読んでレビューを実施
  6. SKILL.md の「Sub-Agent Output Format」に従って結果を返す

  コードの修正は行わず、検出と報告のみ行うこと。
```

#### A-2. 結果の処理

サブエージェントから返された Findings を確認する:

- `要対応` が0件 → `sora-review: ✅ 指摘なし` → STEP B へ
- `要対応` が1件以上 → 修正フローへ

```
sora-review: <N>件（うち修正済み: <M>件、要対応: <K>件）
```

#### A-3. 修正（要対応がある場合）

Findingsの優先度順に修正を実施する:

1. 【重要】/ Critical
2. Should Fix
3. nits

修正時はコードをRead toolで読んでから変更すること。指摘を機械的に適用しない。

#### A-4. テスト実行（必須）

```bash
# Backend（変更がある場合）
cd backend && pytest

# Frontend（変更がある場合）
pnpm -C frontend run type-check
pnpm -C frontend run lint
pnpm -C frontend run test:unit
```

テストが失敗した場合はコミットせず修正して再実行する。

#### A-5. コミット

`/commit-push` スキルを使用してコミット＆プッシュする。

禁止: `fix: sora-reviewの指摘を反映` / `fix: レビュー対応` 等の抽象的表現。
複数テーマにまたがる場合はコミットを分割する。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP B へ

---

### [STEP B] backend-coderabbit / frontend-coderabbit（5並列サブエージェント）

**STEP B はカテゴリごとのサブエージェントを直接起動する（最大10並列）。**

#### B-1. サブエージェント起動

変更ファイルのパスに応じてサブエージェントを起動する。
**backend + frontend 両方の場合は最大10エージェントを並列起動する。**

各サブエージェントの共通プロンプト:

```
あなたはコードレビューのサブエージェントです。

1. チェックリストを読む: `<checklist_path>`
2. コード例示を読む: `<code-examples_path>`
3. 共通フォーマットを読む: `$HOME/.claude/skills/references/review-format.md`
4. プロジェクトの CLAUDE.md を読む
5. `git diff --name-only origin/dev...HEAD -- '<path_filter>'` で変更ファイルを取得
6. 各変更ファイルを読んでレビューを実施（チェックリストの全項目必須）
7. 結果を以下のフォーマットで返す:

| # | File | Severity | Checklist ID | Issue |
|---|------|----------|-------------|-------|

各指摘の詳細（CodeRabbitフォーマット: category + severity + title + explanation + diff）

コードの修正は行わず、検出と報告のみ行うこと。
```

**Backend (5エージェント):**

| # | description | checklist | path_filter |
|---|------------|-----------|-------------|
| 1 | `backend-review: architecture` | `checklists/architecture.md` | `backend/` |
| 2 | `backend-review: type-safety` | `checklists/type-safety.md` | `backend/` |
| 3 | `backend-review: db-performance` | `checklists/db-performance.md` | `backend/` |
| 4 | `backend-review: test-quality` | `checklists/test-quality.md` | `backend/` |
| 5 | `backend-review: security-errors` | `checklists/security-errors.md` | `backend/` |

**Frontend (5エージェント):**

| # | description | checklist | path_filter |
|---|------------|-----------|-------------|
| 1 | `frontend-review: fsd-architecture` | `checklists/fsd-architecture.md` | `frontend/` |
| 2 | `frontend-review: type-state` | `checklists/type-state.md` | `frontend/` |
| 3 | `frontend-review: error-vue` | `checklists/error-vue.md` | `frontend/` |
| 4 | `frontend-review: tanstack-security` | `checklists/tanstack-security.md` | `frontend/` |
| 5 | `frontend-review: test-quality` | `checklists/test-quality.md` | `frontend/` |

チェックリストのベースパス:
- Backend: `$HOME/.claude/skills/backend-coderabbit/`
- Frontend: `$HOME/.claude/skills/frontend-coderabbit/`

#### B-2. 結果の処理

全サブエージェントから返された Findings を集約・重複排除する:

```
backend-coderabbit:
  architecture:      <N>件
  type-safety:       <N>件
  db-performance:    <N>件
  test-quality:      <N>件
  security-errors:   <N>件
  合計:              <N>件（🔴 <n> / 🟠 <n> / 🟡 <n> / 🔵 <n>）

frontend-coderabbit:
  fsd-architecture:  <N>件
  type-state:        <N>件
  error-vue:         <N>件
  tanstack-security: <N>件
  test-quality:      <N>件
  合計:              <N>件（🔴 <n> / 🟠 <n> / 🟡 <n> / 🔵 <n>）
```

全カテゴリゼロなら `✅ 指摘なし` として **STEP C へ進む**。

#### B-3. 修正

Severity順に修正する: 🔴 → 🟠 → 🟡 → 🔵

#### B-4. テスト実行（必須）

A-4 と同じコマンドで全テストを実行する。

#### B-5. コミット

`/commit-push` スキルを使用してコミット＆プッシュする。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP C へ

---

### [STEP C] frontend-architecture（サブエージェント、frontend/ がある場合のみ）

backend のみの場合はこの STEP をスキップして **STEP D へ**。

#### C-1. サブエージェント起動

```
description: "frontend-architecture sub-agent"
prompt: |
  あなたはフロントエンドアーキテクチャチェックのサブエージェントです。

  1. スキルファイルを読む: `$HOME/.claude/skills/frontend-architecture/SKILL.md`
  2. プロジェクトの CLAUDE.md と CODING_STANDARDS.md を読む
  3. `git diff --name-only origin/dev...HEAD -- 'frontend/src/'` で変更ファイルを取得
  4. SKILL.md の全7カテゴリのチェックを実施
  5. 以下の構造で結果を返す:

  ## Findings
  | # | File | Severity | Category | Rule | Issue | Status |
  |---|------|----------|----------|------|-------|--------|

  ## Out of Scope
  | # | Item | Reason |
  |---|------|--------|

  ## Summary
  - Total findings: N
  - 🔴 MUST: N / 🟠 SHOULD: N / 🟡 Soft: N / 🔵 MAY: N

  コードの修正は行わず、検出と報告のみ行うこと。
```

#### C-2. 結果の処理

```
frontend-architecture: <N>件（🔴 <n> / 🟠 <n> / 🟡 <n> / 🔵 <n>）
```

0件なら `✅ 指摘なし` として修正・コミットをスキップ。

#### C-3. 修正

Severity順に修正する。

#### C-4. テスト実行（必須）

A-4 と同じコマンドで全テストを実行する。

#### C-5. コミット

`/commit-push` スキルを使用してコミット＆プッシュする。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → STEP D へ

---

### [STEP D] codex review CLI（常に実行・Bash直接）

`codex review` CLI を使い、Claude 系スキルとは異なる視点でコードレビューを実施する。
**これはサブエージェントではなくBash直接実行（外部CLIツール）。**

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

A-3 と同様に優先度順で修正する。

#### D-4. テスト実行（必須）

A-4 と同じコマンドで全テストを実行する。

#### D-5. コミット

`/commit-push` スキルを使用してコミット＆プッシュする。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → ラウンドサマリーへ

---

### ラウンドサマリー

```
=== Round <N> Summary ===
[STEP A] sora-review:              <N>件 / ✅ 指摘なし
[STEP B] backend-coderabbit:
           architecture:           <N>件 / ✅
           type-safety:            <N>件 / ✅
           db-performance:         <N>件 / ✅
           test-quality:           <N>件 / ✅
           security-errors:        <N>件 / ✅
[STEP B] frontend-coderabbit:
           fsd-architecture:       <N>件 / ✅
           type-state:             <N>件 / ✅
           error-vue:              <N>件 / ✅
           tanstack-security:      <N>件 / ✅
           test-quality:           <N>件 / ✅
[STEP C] frontend-architecture:    <N>件 / ✅ 指摘なし  （該当する場合）
[STEP D] codex review:             <N>件 / ✅ 指摘なし
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
  [STEP B] backend-coderabbit:    ✅ 指摘なし (5/5 categories)
  [STEP B] frontend-coderabbit:   ✅ 指摘なし (5/5 categories)
  [STEP C] frontend-architecture: ✅ 指摘なし  （該当する場合）
  [STEP D] codex review:          ✅ 指摘なし

# プロンプトファイルのクリーンアップ
rm -f "$SORA_PROMPT"

全スキルで指摘なしを確認しました。コードをプッシュしてください。
```

---

## Red Flags - Never Do This

- **コンテキスト80%超えのまま `/compact` せずに次ステップへ進まない**
- **テストが失敗したままコミットしない**
- **サブエージェントのFindingsを読まずに「指摘なし」と判定しない**
- **`fix: レビュー対応` 等の抽象的なコミットメッセージを使わない**
- **STEP A → B → C → D の順番を変えない**
- **1ステップでも指摘があればラウンドを最初から回し直す**
- **サブエージェントにコード修正をさせない（検出と報告のみ）**
- **STEP B のカテゴリ別サブエージェントを直列で実行しない（必ず並列起動）**
