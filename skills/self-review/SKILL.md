---
name: self-review
description: 全工程をサブエージェントに委託する完全オーケストレーター。REVIEW(並列)→TRIAGE(エージェント)→FIX(エージェント)→COMMIT。CCはエージェント起動と結果サマリーの確認のみ。
---

# Self Review Orchestrator

**CCは純粋なオーケストレーター。** レビュー・妥当性判断・実装の全てをサブエージェントに委託し、CCはエージェントの起動と結果サマリーの確認のみ行う。

**Announce at start:** "self-review を開始します。全工程エージェント委託で全指摘ゼロを目指します。"

## エンジン選択

`$ARGUMENTS` に `--codex` が含まれる場合は codex CLI を使用する。それ以外は **Claude Code Agent（デフォルト）** を使用する。

```
USE_CODEX = "--codex" in $ARGUMENTS
```

---

## CCの役割（厳守）

CCがやること:
- レビューエージェント（または codex review）を起動する
- **サマリー結果**を読む（詳細はエージェント内で完結）
- ループ継続/終了を判断する
- `/commit-push` でコミットする

CCがやらないこと:
- コードを読む（エージェントがやる）
- レビューする（エージェント/codexがやる）
- 妥当性を判断する（エージェントがやる）
- コードを修正する（エージェントがやる）

---

## コンテキスト管理（最優先ルール）

**各 PHASE の終わりにコンテキスト使用率を確認し、80% 以上なら即 `/compact` する。**

- compact 後もループは継続する
- **全工程エージェント/codex委託により、CCのコンテキスト消費は最小限**

---

## セットアップ

### 変更ファイルの確認

```bash
git diff --name-only origin/dev...HEAD
```

変更ファイルが0件の場合は「レビュー対象の変更がありません」と報告して終了。

変更パスから `HAS_BACKEND`（`backend/` あり）、`HAS_FRONTEND`（`frontend/` あり）を判定する。

---

## メインループ

```
=== Self Review Round <N> ===
```

---

### PHASE 1: REVIEW（並列レビュー）

**全レビューを並列実行する。** CCはレビューを行わず、結果を待つだけ。

**注意:** `HAS_BACKEND=false` の場合は backend レビューを丸ごとスキップ、`HAS_FRONTEND=false` の場合は frontend レビューを丸ごとスキップする。

#### 1-A: Claude Code Agent（デフォルト）

**最大11個の Agent tool を単一メッセージで並列起動する。**

- **Backend（HAS_BACKEND の場合）:** architecture, type-safety, db-performance, test-quality, security-errors の5つ
- **Frontend（HAS_FRONTEND の場合）:** fsd-architecture, type-state, error-vue, tanstack-security, test-quality の5つ
- **General（常時）:** 1つ

各チェックリスト Agent:

```
description: "review: <be/fe>-<category>"
prompt: |
  あなたはコードレビューのサブエージェントです。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. チェックリストファイルを読む: ~/.claude/skills/<backend-coderabbit or frontend-coderabbit>/checklists/<category>.md
  3. コード例ファイルを読む: ~/.claude/skills/<backend-coderabbit or frontend-coderabbit>/references/code-examples.md
  4. 以下のコマンドで差分を取得:
     git diff origin/dev...HEAD -- <backend/ or frontend/>
  5. チェックリストに沿って差分をレビューする

  出力フォーマット:
  | # | File:Line | Severity (🔴/🟠/🟡/🔵) | Checklist ID | Issue |
  指摘なしの場合: "No findings."
```

General Agent:

```
description: "review: general"
prompt: |
  あなたは一般的なコードレビューのサブエージェントです。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. .claude/plan.md があれば読む
  3. 以下のコマンドで差分を取得:
     git diff origin/dev...HEAD
  4. 全体的な観点（設計整合性、命名、プラン通りの実装か）でレビューする

  出力フォーマット:
  | # | File:Line | Severity (🔴/🟠/🟡/🔵) | Issue |
  指摘なしの場合: "No findings."
```

全 Agent を **同時に起動** すること（単一メッセージに全ての Agent tool call）。

#### 1-B: codex CLI（--codex 指定時）

```bash
SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_MD="$(pwd)/CLAUDE.md"
RESULTS_DIR=$(mktemp -d /tmp/self-review.XXXXXX)

# --- Backend checklists (HAS_BACKEND の場合のみ) ---
for cat in architecture type-safety db-performance test-quality security-errors; do
  PROMPT="$RESULTS_DIR/prompt-be-${cat}.txt"
  {
    echo "# Project Rules"
    [ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD"
    echo -e "\n---\n# Checklist"
    cat "$SKILLS_DIR/backend-coderabbit/checklists/${cat}.md"
    echo -e "\n---\n# Code Examples"
    cat "$SKILLS_DIR/backend-coderabbit/references/code-examples.md"
    echo -e "\n---"
    echo "Backend code review. Check changed backend/ files against the checklist. Report findings only."
    echo "Output: | # | File:Line | Severity (🔴/🟠/🟡/🔵) | Checklist ID | Issue |"
    echo 'If no issues: "No findings."'
    echo -e "\n---\n# Git diff (changes to review)\n"
    git diff origin/dev...HEAD -- backend/
  } > "$PROMPT"
  codex review - < "$PROMPT" > "$RESULTS_DIR/be-${cat}.txt" 2>&1 &
done

# --- Frontend checklists (HAS_FRONTEND の場合のみ) ---
for cat in fsd-architecture type-state error-vue tanstack-security test-quality; do
  PROMPT="$RESULTS_DIR/prompt-fe-${cat}.txt"
  {
    echo "# Project Rules"
    [ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD"
    echo -e "\n---\n# Checklist"
    cat "$SKILLS_DIR/frontend-coderabbit/checklists/${cat}.md"
    echo -e "\n---\n# Code Examples"
    cat "$SKILLS_DIR/frontend-coderabbit/references/code-examples.md"
    echo -e "\n---"
    echo "Frontend code review. Check changed frontend/ files against the checklist. Report findings only."
    echo "Output: | # | File:Line | Severity (🔴/🟠/🟡/🔵) | Checklist ID | Issue |"
    echo 'If no issues: "No findings."'
    echo -e "\n---\n# Git diff (changes to review)\n"
    git diff origin/dev...HEAD -- frontend/
  } > "$PROMPT"
  codex review - < "$PROMPT" > "$RESULTS_DIR/fe-${cat}.txt" 2>&1 &
done

# --- General codex review (常時) ---
GENERAL_PROMPT="$RESULTS_DIR/prompt-general.txt"
{
  echo "# Project Rules"
  [ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD"
  PLAN_FILE=".claude/plan.md"
  if [ -f "$PLAN_FILE" ]; then
    echo -e "\n---\n# Implementation Plan"
    cat "$PLAN_FILE"
  fi
  echo -e "\n---\n# Git diff (changes to review)\n"
  git diff origin/dev...HEAD
} > "$GENERAL_PROMPT"
codex review - < "$GENERAL_PROMPT" > "$RESULTS_DIR/general.txt" 2>&1 &

wait
```

#### 結果収集

**1-A の場合:** 各 Agent の返り値を収集する。
**1-B の場合:**

```bash
echo "=== Review Results ==="
for f in "$RESULTS_DIR"/*.txt; do
  [[ "$(basename "$f")" == prompt-* ]] && continue
  echo "--- $(basename "$f" .txt) ---"
  cat "$f"
  echo
done
rm -rf "$RESULTS_DIR"
```

#### ↓ コンテキスト確認 → 80% 以上なら `/compact`

---

### PHASE 2: TRIAGE（サブエージェントが妥当性を判断）

**CCはTRIAGEを行わない。** triage エージェントに全 findings と判断基準を渡し、結果サマリーだけ受け取る。

#### 2-1. triage エージェント起動

Agent tool で起動する:

```
description: "triage: judge validity of review findings"
prompt: |
  あなたはレビュー指摘の妥当性を判断するサブエージェントです。

  ## 全 findings
  <PHASE 1 の codex review 結果をここに貼る>

  ## タスク

  ### Step 1: 重複排除
  全 findings をマージし、同じファイル・同じ行・同じ内容の重複を排除する。

  ### Step 2: 妥当性判断
  各 finding について:

  1. **対象コードを Read tool で読む**（必須。コードを読まずに判断しない）
  2. **プロジェクトの CLAUDE.md を読む**
  3. **CODING_STANDARDS.md があれば読む**
  4. 以下の基準で判定:

  | 判定 | 基準 |
  |------|------|
  | **妥当** | バグ・ルール違反・型安全性・命名不備・セキュリティ問題 |
  | **妥当でない** | 事実と異なる・ルールと矛盾・意図的設計・過剰な指摘・好みの問題 |

  ### Step 3: 結果レポート
  以下の形式で返す:

  ## Triage Result
  - **全 findings:** N件
  - **妥当:** M件
  - **除外:** K件

  ### 除外した指摘
  | # | Source | Issue | 除外理由 |
  |---|--------|-------|---------|

  ### 妥当な指摘（codex-fix に渡す）
  | # | Source | File | Line | Severity | Issue |
  |---|--------|------|------|----------|-------|

  各妥当な指摘の詳細:
  - **ファイル:** path
  - **行:** N
  - **問題:** 説明
  - **修正方針:** 具体的にどう直すべきか
```

#### 2-2. 結果の確認

triage エージェントの結果をテーブルで表示する（数字だけでなく詳細を見せる）:

```markdown
=== PHASE 2: TRIAGE ===
全 findings: <N>件 → 妥当: <M>件 / 除外: <K>件

### 妥当な指摘
| # | Source | File | Severity | Issue |
|---|--------|------|----------|-------|
| 1 | be-architecture | path/to/file.py:42 | 🔴 | 簡潔な説明 |
| 2 | fe-type-state | path/to/file.ts:100 | 🟠 | 簡潔な説明 |

### 除外した指摘
| # | Source | Issue | 除外理由 |
|---|--------|-------|---------|
| 1 | be-type-safety | 型安全性の指摘 | 意図的設計 |
```

**妥当な指摘が0件 → ✅ 全指摘なし → ループ終了（完了レポートへ）**

#### ↓ コンテキスト確認 → 80% 以上なら `/compact`

---

### PHASE 3: FIX（plan + 実装）

**CCは実装しない。fix エージェントに plan 作成と実装を委託する。**

#### 3-1. fix エージェント起動

Agent tool で起動する。**triage エージェントが返した「妥当な指摘」セクションをそのまま渡す。**

**USE_CODEX の場合は codex cli で実装、それ以外は Agent が直接実装する。**

##### 3-1-A: Claude Code Agent（デフォルト）

```
description: "fix: plan and implement review findings"
prompt: |
  あなたはコード修正のサブエージェントです。
  レビュー指摘を受けて、plan を作成し、直接実装します。

  ## 妥当な指摘一覧
  <triage エージェントの「妥当な指摘」セクションをここに貼る>

  ## タスク

  ### Step 1: Plan 作成
  1. プロジェクトの CLAUDE.md を読む
  2. 各指摘の対象ファイルを Read tool で読む
  3. 修正計画を `.claude/self-review-fix-plan.md` に書き出す:
     - 指摘ごとに: 対象ファイル、修正方針、期待される変更
     - 修正順序（依存関係を考慮）
     - テスト追加が必要な場合はその計画も含める

  ### Step 2: 実装
  plan に従い、Edit tool / Write tool でコードを修正する。
  Rules:
  1. Fix all items in the order specified
  2. Follow project conventions strictly
  3. Add tests if the plan requires them
  4. Do not add extra changes beyond the plan
  5. Do not refactor unrelated code

  ### Step 3: テスト実行
  Backend: cd backend && pytest
  Frontend: pnpm -C frontend run type-check && pnpm -C frontend run lint && pnpm -C frontend run test:unit

  テストが失敗した場合: エラー内容を分析し修正（最大3回リトライ）。3回失敗したら失敗レポートを返す。

  ### Step 4: 結果レポート
  ## Fix Result
  - **Plan items:** N
  - **Fixed:** N
  - **Failed:** N (details if any)
  - **Test result:** PASS / FAIL

  修正されたファイル一覧:
  | # | File | What changed |
  |---|------|-------------|

  `.claude/self-review-fix-plan.md` は削除しないこと（CC側で確認に使う）。
```

##### 3-1-B: codex CLI（--codex 指定時）

```
description: "codex-fix: plan and implement review findings"
prompt: |
  あなたはコード修正のサブエージェントです。
  レビュー指摘を受けて、plan を作成し、codex cli で実装します。

  ## 妥当な指摘一覧
  <triage エージェントの「妥当な指摘」セクションをここに貼る>

  ## タスク

  ### Step 1: Plan 作成
  1. プロジェクトの CLAUDE.md を読む
  2. 各指摘の対象ファイルを Read tool で読む
  3. 修正計画を `.claude/self-review-fix-plan.md` に書き出す

  ### Step 2: codex cli で実装
  ```bash
  CLAUDE_MD="$(pwd)/CLAUDE.md"
  PLAN=".claude/self-review-fix-plan.md"

  PROMPT=$(mktemp /tmp/codex-fix.XXXXXX)
  echo "# Project Rules (MUST follow)" > "$PROMPT"
  [ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
  echo -e "\n---\n# Fix Plan\n" >> "$PROMPT"
  cat "$PLAN" >> "$PROMPT"
  echo -e "\n---\n" >> "$PROMPT"
  cat << 'INSTRUCTIONS' >> "$PROMPT"
  Implement the fix plan above exactly as specified.
  Rules:
  1. Fix all items in the order specified
  2. Follow project conventions strictly
  3. Add tests if the plan requires them
  4. Do not add extra changes beyond the plan
  5. Do not refactor unrelated code
  INSTRUCTIONS

  codex - < "$PROMPT"
  rm -f "$PROMPT"
  ```

  ### Step 3: テスト実行
  テストが失敗した場合: plan を修正して再度 codex cli（最大3回リトライ）

  ### Step 4: 結果レポート
  `.claude/self-review-fix-plan.md` は削除しないこと。
```

#### 3-2. 結果の確認

codex-fix エージェントの結果サマリーを確認する:

- **全件 Fixed + テスト PASS** → PHASE 4 へ
- **一部 Failed** → 失敗した項目をログに記録し、PHASE 4 へ（次ラウンドで再検出される）

```
=== PHASE 3: CODEX-FIX ===
Fixed: <N>/<M>件
Test: PASS / FAIL
Codex cli rounds: <N>
```

#### 3-3. クリーンアップ

```bash
rm -f .claude/self-review-fix-plan.md
```

#### ↓ コンテキスト確認 → 80% 以上なら `/compact`

---

### PHASE 4: COMMIT

`/commit-push` スキルを使用してコミット＆プッシュする。

禁止: `fix: レビュー対応` 等の抽象的表現。
複数テーマにまたがる場合はコミットを分割する。

#### ↓ コンテキスト確認 → 80% 以上なら `/compact` → ラウンドサマリーへ

---

### ラウンドサマリー

```markdown
=== Round <N> Summary ===

PHASE 1 - REVIEW: <N>件検出
| Source | Findings |
|--------|----------|
| be-architecture | <N> |
| fe-type-state | <N> |
| general | <N> |

PHASE 2 - TRIAGE: 妥当 <M>件 / 除外 <K>件

| # | File | Severity | Issue | 判定 |
|---|------|----------|-------|------|
| 1 | path/to/file.py:42 | 🔴 | 説明 | ✅ 妥当 |
| 2 | path/to/file.ts:10 | 🟡 | 説明 | ❌ 除外: 理由 |

PHASE 3 - FIX: Fixed <N>/<M>件 / Test: PASS
```

**PHASE 2 で妥当な指摘が 0件 → ループ終了（完了レポートへ）**
**1件以上 → Round <N+1> へ**

---

## 完了レポート

```
=== Self Review Complete ===

総ラウンド数: <N>
総指摘検出数: <N>（うち妥当: <M>、除外: <K>）
総修正数:     <M>

ラウンド別サマリー:
| Round | 検出 | 妥当 | 除外 | 修正 | テスト |
|-------|------|------|------|------|--------|
| 1 | <N> | <M> | <K> | <N> | PASS |
| 2 | <N> | <M> | <K> | <N> | PASS |
| ... | | | | | |

全レビューで指摘なしを確認しました。
```

---

## Red Flags - Never Do This

- **CCが直接コードを読まない** — コード確認はエージェント内で完結させる
- **CCが直接コードを修正しない** — 実装は全て fix エージェントに委託（デフォルト: Agent直接実装、--codex: codex cli）
- **CCが妥当性判断しない** — TRIAGE は triage エージェントに委託する
- **コンテキスト80%超えのまま `/compact` せずに次PHASEへ進まない**
- **テストが失敗したままコミットしない**
- **サブエージェントの結果サマリーを確認せずに次へ進まない**
- **`fix: レビュー対応` 等の抽象的なコミットメッセージを使わない**
- **レビューを直列で実行しない（必ず並列起動）**
- **fix エージェントにレビューをさせない（fix は修正のみ）**
- **PHASE 順序を変えない（REVIEW → TRIAGE → FIX → COMMIT）**
- **エージェントの詳細結果をCCのコンテキストに展開しない** — サマリーだけ確認する
