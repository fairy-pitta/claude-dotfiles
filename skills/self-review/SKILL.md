---
name: self-review
description: 全工程をサブエージェントに委託する完全オーケストレーター。REVIEW(並列)→TRIAGE(エージェント)→CODEX-FIX(エージェント)→COMMIT。CCはエージェント起動と結果サマリーの確認のみ。
---

# Self Review Orchestrator

**CCは純粋なオーケストレーター。** レビュー・妥当性判断・実装の全てをサブエージェントに委託し、CCはエージェントの起動と結果サマリーの確認のみ行う。

**Announce at start:** "self-review を開始します。全工程エージェント委託で全指摘ゼロを目指します。"

---

## CCの役割（厳守）

CCがやること:
- エージェントを起動する
- エージェントの**サマリー結果**を読む（詳細はエージェント内で完結）
- ループ継続/終了を判断する
- `/commit-push` でコミットする

CCがやらないこと:
- コードを読む（エージェントがやる）
- レビューする（エージェントがやる）
- 妥当性を判断する（エージェントがやる）
- コードを修正する（エージェントがやる）

---

## コンテキスト管理（最優先ルール）

**各 PHASE の終わりにコンテキスト使用率を確認し、80% 以上なら即 `/compact` する。**

- compact 後もループは継続する
- **全工程エージェント委託により、CCのコンテキスト消費は最小限**

---

## セットアップ

### 変更ファイルの確認

```bash
git diff --name-only origin/dev...HEAD
```

変更ファイルが0件の場合は「レビュー対象の変更がありません」と報告して終了。

変更パスから `HAS_BACKEND`（`backend/` あり）、`HAS_FRONTEND`（`frontend/` あり）を判定する。

### codex review 用プロンプト準備

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"
SKILLS_DIR="$HOME/.claude/skills"

CODEX_PROMPT=$(mktemp /tmp/self-review-codex.XXXXXX)
echo "# Project Rules (CLAUDE.md)" > "$CODEX_PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$CODEX_PROMPT"
echo -e "\n---\n" >> "$CODEX_PROMPT"
PLAN_FILE=".claude/plan.md"
if [ -f "$PLAN_FILE" ]; then
  echo "# Implementation Plan" >> "$CODEX_PROMPT"
  cat "$PLAN_FILE" >> "$CODEX_PROMPT"
  echo -e "\n---\n" >> "$CODEX_PROMPT"
fi
cat "$SKILLS_DIR/sora-review/SKILL.md" >> "$CODEX_PROMPT"
```

---

## メインループ

```
=== Self Review Round <N> ===
```

---

### PHASE 1: REVIEW（全レビューを並列サブエージェントに委託）

**全レビューエージェントを同一メッセージで並列起動する。**
CCはレビューを行わず、結果を待つだけ。

#### 起動するエージェント一覧

| # | Agent | 条件 | description |
|---|-------|------|-------------|
| 1 | sora-review | 常時 | `sora-review sub-agent` |
| 2-6 | backend-coderabbit 5並列 | HAS_BACKEND | `backend-review: {category}` |
| 7-11 | frontend-coderabbit 5並列 | HAS_FRONTEND | `frontend-review: {category}` |
| 12 | frontend-architecture | HAS_FRONTEND | `frontend-architecture sub-agent` |

**最大12エージェント同時起動。** 条件に該当しないものはスキップ。

#### sora-review プロンプト

```
あなたはコードレビューのサブエージェントです。

1. `$HOME/.claude/skills/sora-review/SKILL.md` を読む
2. `$HOME/.claude/skills/sora-review/references/` 配下を全て読む
3. プロジェクトの CLAUDE.md を読む
4. `git diff --name-only origin/dev...HEAD` で変更ファイルを取得
5. 各変更ファイルを読んでレビュー
6. 「Sub-Agent Output Format」で結果を返す

コードの修正は行わず、検出と報告のみ。
```

#### coderabbit 5並列プロンプト（backend / frontend 共通）

```
あなたはコードレビューのサブエージェントです。

1. チェックリストを読む: `<checklist_path>`
2. コード例示を読む: `<skill_dir>/references/code-examples.md`
3. 共通フォーマットを読む: `$HOME/.claude/skills/references/review-format.md`
4. プロジェクトの CLAUDE.md を読む
5. `git diff --name-only origin/dev...HEAD -- '<path_filter>'` で変更ファイルを取得
6. 各変更ファイルを読んでレビュー（全項目必須）
7. 結果を返す:

| # | File | Severity | Checklist ID | Issue |
|---|------|----------|-------------|-------|

各指摘の詳細（CodeRabbitフォーマット: category + severity + title + explanation + diff）

コードの修正は行わず、検出と報告のみ。
```

**Backend 5エージェント:**

| description | checklist | path_filter |
|------------|-----------|-------------|
| `backend-review: architecture` | `backend-coderabbit/checklists/architecture.md` | `backend/` |
| `backend-review: type-safety` | `backend-coderabbit/checklists/type-safety.md` | `backend/` |
| `backend-review: db-performance` | `backend-coderabbit/checklists/db-performance.md` | `backend/` |
| `backend-review: test-quality` | `backend-coderabbit/checklists/test-quality.md` | `backend/` |
| `backend-review: security-errors` | `backend-coderabbit/checklists/security-errors.md` | `backend/` |

**Frontend 5エージェント:**

| description | checklist | path_filter |
|------------|-----------|-------------|
| `frontend-review: fsd-architecture` | `frontend-coderabbit/checklists/fsd-architecture.md` | `frontend/` |
| `frontend-review: type-state` | `frontend-coderabbit/checklists/type-state.md` | `frontend/` |
| `frontend-review: error-vue` | `frontend-coderabbit/checklists/error-vue.md` | `frontend/` |
| `frontend-review: tanstack-security` | `frontend-coderabbit/checklists/tanstack-security.md` | `frontend/` |
| `frontend-review: test-quality` | `frontend-coderabbit/checklists/test-quality.md` | `frontend/` |

#### frontend-architecture プロンプト

```
あなたはフロントエンドアーキテクチャチェックのサブエージェントです。

1. `$HOME/.claude/skills/frontend-architecture/SKILL.md` を読む
2. プロジェクトの CLAUDE.md と CODING_STANDARDS.md を読む
3. `git diff --name-only origin/dev...HEAD -- 'frontend/src/'` で変更ファイルを取得
4. SKILL.md の全7カテゴリをチェック
5. Findings テーブル + Summary で結果を返す

コードの修正は行わず、検出と報告のみ。
```

#### codex review CLI（Bash 直接）

レビューエージェントの返答を待っている間に、codex review を並行で実行する:

```bash
codex review --base dev - < "$CODEX_PROMPT"
```

#### ↓ 全エージェント完了 + codex review 完了 → PHASE 2 へ

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
  <PHASE 1 の全エージェント + codex review の結果をここに貼る>

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

triage エージェントの結果サマリーを確認する:

```
=== PHASE 2: TRIAGE ===
全 findings: <N>件 → 妥当: <M>件 / 除外: <K>件
```

**妥当な指摘が0件 → ✅ 全指摘なし → ループ終了（完了レポートへ）**

#### ↓ コンテキスト確認 → 80% 以上なら `/compact`

---

### PHASE 3: CODEX-FIX（plan + codex exec で実装）

**CCは実装しない。codex-fix エージェントに plan 作成と実装を委託する。**

#### 3-1. codex-fix エージェント起動

Agent tool で起動する。**triage エージェントが返した「妥当な指摘」セクションをそのまま渡す。**

```
description: "codex-fix: plan and implement review findings"
prompt: |
  あなたはコード修正のサブエージェントです。
  レビュー指摘を受けて、plan を作成し、codex exec で実装します。

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

  ### Step 2: codex exec で実装
  以下の bash コマンドで codex に実装を委譲する:

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

  codex exec - < "$PROMPT"
  rm -f "$PROMPT"
  ```

  ### Step 3: テスト実行
  ```bash
  # Backend
  cd backend && pytest

  # Frontend
  pnpm -C frontend run type-check
  pnpm -C frontend run lint
  pnpm -C frontend run test:unit
  ```

  テストが失敗した場合:
  - エラー内容を分析し、plan を修正して再度 codex exec（最大3回リトライ）
  - 3回失敗したら失敗レポートを返す

  ### Step 4: 結果レポート
  以下の形式で返す:

  ## Fix Result
  - **Plan items:** N
  - **Fixed:** N
  - **Failed:** N (details if any)
  - **Test result:** PASS / FAIL
  - **Codex exec rounds:** N

  修正されたファイル一覧:
  | # | File | What changed |
  |---|------|-------------|

  `.claude/self-review-fix-plan.md` は削除しないこと（CC側で確認に使う）。
```

#### 3-2. 結果の確認

codex-fix エージェントの結果サマリーを確認する:

- **全件 Fixed + テスト PASS** → PHASE 4 へ
- **一部 Failed** → 失敗した項目をログに記録し、PHASE 4 へ（次ラウンドで再検出される）

```
=== PHASE 3: CODEX-FIX ===
Fixed: <N>/<M>件
Test: PASS / FAIL
Codex exec rounds: <N>
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

```
=== Round <N> Summary ===

PHASE 1 - REVIEW:
  sora-review:           <N>件
  backend-coderabbit:    <N>件 (arch:<n> type:<n> db:<n> test:<n> sec:<n>)
  frontend-coderabbit:   <N>件 (fsd:<n> type:<n> err:<n> tanstack:<n> test:<n>)
  frontend-architecture: <N>件
  codex review:          <N>件
  合計:                  <N>件

PHASE 2 - TRIAGE:
  妥当: <M>件 / 除外: <K>件

PHASE 3 - CODEX-FIX:
  Fixed: <N>/<M>件 / Test: PASS
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

# クリーンアップ
rm -f "$CODEX_PROMPT"

全レビューで指摘なしを確認しました。
```

---

## Red Flags - Never Do This

- **CCが直接コードを読まない** — コード確認はエージェント内で完結させる
- **CCが直接コードを修正しない** — 実装は全て codex-fix エージェント経由で codex exec に委託
- **CCが妥当性判断しない** — TRIAGE は triage エージェントに委託する
- **コンテキスト80%超えのまま `/compact` せずに次PHASEへ進まない**
- **テストが失敗したままコミットしない**
- **サブエージェントの結果サマリーを確認せずに次へ進まない**
- **`fix: レビュー対応` 等の抽象的なコミットメッセージを使わない**
- **レビューエージェントを直列で実行しない（必ず並列起動）**
- **codex-fix エージェントにレビューをさせない（codex-fix は修正のみ）**
- **PHASE 順序を変えない（REVIEW → TRIAGE → CODEX-FIX → COMMIT）**
- **エージェントの詳細結果をCCのコンテキストに展開しない** — サマリーだけ確認する
