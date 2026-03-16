---
name: codex-plan
description: Plan作成 → レビューループ（LGTM まで） → ユーザー承認 → 実装の一連フロー。プラン検証と実装をサブエージェントに委譲する。（デフォルト: CC Agent、--codex で codex CLI）
---

# Codex Plan

Plan Mode でプランを作成し、レビュー・検証を繰り返してから、ユーザー承認を経て実装を委譲するスキル。

Context: $ARGUMENTS

**Announce at start:** "codex-plan を開始します。Plan作成 → レビューループ → ユーザー承認 → 実装 の流れで進めます。"

## エンジン選択

`$ARGUMENTS` に `--codex` が含まれる場合は codex CLI を使用する。それ以外は **Claude Code Agent（デフォルト）** を使用する。

```
USE_CODEX = "--codex" in $ARGUMENTS
```

---

## コンテキスト管理（最優先ルール）

**各フェーズ境界でコンテキスト使用率を確認し、80% 以上なら `/compact` してから続行する。**

---

## Phase 1: 要件整理

### 1-1. 入力の解釈

- `$ARGUMENTS` に GitHub Issue 番号/URL がある場合: `gh issue view` で取得
- `$ARGUMENTS` にインライン指示がある場合: そのまま要件として使用
- `$ARGUMENTS` が空の場合: ユーザーに何を作るか確認

### 1-2. コードベース調査（Explore エージェント）

Agent tool で Explore エージェントを起動し、コードベースの構造を把握する:

```
subagent_type: "Explore"
description: "codebase exploration for plan"
prompt: |
  以下の観点でコードベースを調査し、プラン作成に必要な情報をまとめてください:

  1. プロジェクトの全体アーキテクチャ（ディレクトリ構成、主要モジュール）
  2. 今回の要件に関連するファイル群（パス付き）
  3. 既存の設計パターンと規約（命名規則、レイヤー構成など）
  4. テストの構造と規約
  5. 関連する既存の実装（類似機能があれば）

  要件: <$ARGUMENTS の要約をここに記載>

  簡潔にまとめること。コード例は不要、パスと概要のみ。
```

Explore エージェントの結果をメモし、Phase 2 で活用する。

#### Context check -> `/compact` if >= 80%

---

## Phase 2: Plan 作成（Plan Mode）

### 2-1. Plan Mode に入る

Plan Mode に入り、Phase 1 の調査結果をもとに詳細なプランを作成する。

プランに含める項目:

- **Goal**: 何を作る/直すのか、なぜか
- **Scope**: 変更対象のファイル一覧（絶対パス付き）
- **Phases**: 順序付きの実装ステップ（各ステップに具体的な変更方針を記載）
- **Testing strategy**: 追加/変更するテスト（テスト関数名の命名案も含む）
- **Verification**: 各ステップの検証方法
- **Risks**: 破壊的変更、マイグレーション、パフォーマンスのリスク

### 2-2. プランをファイルに保存

`.claude/plan.md` に保存する。

**この時点ではコードを一切変更しない。**

#### Context check -> `/compact` if >= 80%

---

## Phase 3: プランレビューループ

### 3-1. レビュー実行

#### 3-1-A: Claude Code Agent（デフォルト）

Agent tool で起動する:

```
description: "plan review agent"
prompt: |
  あなたはプランレビューのサブエージェントです。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. `.claude/plan.md` を読む
  3. 以下の基準で評価する:
     - Architectural correctness: プロジェクトの既存パターン・規約に従っているか
     - Completeness: 不足しているステップや未考慮のエッジケースがないか
     - Step ordering: ステップ間の依存関係が守られているか
     - Testing coverage: 適切なテストが計画されているか
     - Risk assessment: 破壊的変更・マイグレーション問題が特定されているか
     - Scope appropriateness: 過剰/不足なく適切なスコープか

  プランが良ければ: "LGTM" とだけ返す
  問題があれば: 具体的な改善提案を簡潔にリストする
```

#### 3-1-B: codex CLI（--codex 指定時）

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"
PLAN_FILE=".claude/plan.md"

PROMPT=$(mktemp /tmp/codex-plan-review.XXXXXX)

echo "# Project Rules" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Implementation Plan to Review\n" >> "$PROMPT"
cat "$PLAN_FILE" >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << 'REVIEW_INSTRUCTIONS' >> "$PROMPT"
You are reviewing an implementation plan before it gets executed.
Evaluate it against these criteria:

1. **Architectural correctness**: Does it follow the project's existing patterns and conventions?
2. **Completeness**: Are there missing steps or unconsidered edge cases?
3. **Step ordering**: Are dependencies between steps respected?
4. **Testing coverage**: Are adequate tests planned with proper naming?
5. **Risk assessment**: Are potential breaking changes and migration issues identified?
6. **Scope appropriateness**: Is the plan appropriately scoped — not over-engineered, not under-specified?

If the plan is solid and ready for implementation, respond with exactly: LGTM

If there are issues, list them concisely with specific suggestions for improvement.
Each issue should be actionable — state what to change, not just what's wrong.
REVIEW_INSTRUCTIONS

codex review - < "$PROMPT"
rm -f "$PROMPT"
```

### 3-2. 結果の解析

レビューの出力を解析する:

- **LGTM（またはアクショナブルな指摘なし）**: Phase 4 へ進む
- **指摘あり**: 3-3 のプラン修正エージェントへ

### 3-3. プラン修正（サブエージェント）

指摘がある場合、Agent tool でプラン修正エージェントを起動する:

```
description: "plan revision agent"
prompt: |
  あなたはプラン修正のサブエージェントです。

  ## レビューからの指摘:
  <レビューの出力をここに貼る>

  ## タスク:
  1. `.claude/plan.md` を Read tool で読む
  2. プロジェクトの CLAUDE.md を読む（規約確認用）
  3. 指摘を一つずつ検討し、プランを修正する
  4. 修正後のプランを `.claude/plan.md` に Edit tool で書き戻す
  5. 修正内容のサマリーを返す（何をどう変えたか）

  プランの修正のみ行い、コードは一切変更しないこと。
```

修正サマリーを記録し、再度 3-1 に戻る。

### 3-4. ループ制御

- **最大 5 ラウンド**
- 5 ラウンド後も指摘が残る場合: 残りの懸念事項をユーザーに提示して判断を仰ぐ

### 3-5. ラウンドサマリー

各ラウンド後に表示:

```
=== Plan Review: Round <N>/<5> ===
Status: LGTM / <N>件の指摘あり
修正内容: <修正のサマリー>（修正した場合）
```

#### Context check -> `/compact` if >= 80%

---

## Phase 4: ユーザー承認

### 4-1. 承認済みプランの提示

Plan Mode を終了し、`.claude/plan.md` の内容を全文表示する:

```
=== Approved Plan ===
Review rounds: <N>

<plan.md の全文>
```

### 4-2. ユーザーの判断を待つ

**ユーザーが承認するまで一切コードを変更しない。**

- **OK / 承認 / LGTM**: Phase 5 へ
- **修正要望あり**: プランを修正 → Phase 3 に戻って再レビュー（ラウンドカウントはリセット）
- **却下 / キャンセル**: `.claude/plan.md` を削除してスキル終了

---

## Phase 5: 実装を委譲

### 5-1. 実装実行

#### 5-1-A: Claude Code Agent（デフォルト）

Agent tool で実装エージェントを起動する:

```
description: "implement: execute approved plan"
prompt: |
  あなたは実装のサブエージェントです。承認済みプランを実装します。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. `.claude/plan.md` を読む
  3. plan に従い、Edit tool / Write tool でコードを修正・作成する

  Rules:
  1. Implement all steps in the order specified
  2. Follow the project conventions strictly
  3. Add all planned tests
  4. Run tests after implementation to verify correctness
  5. Do not deviate from the plan
  6. Do not add extra features, refactoring, or improvements beyond the plan

  結果レポート:
  - 修正/作成ファイル一覧
  - テスト結果: PASS / FAIL
```

#### 5-1-B: codex CLI（--codex 指定時）

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"
PLAN_FILE=".claude/plan.md"

PROMPT=$(mktemp /tmp/codex-plan-exec.XXXXXX)

echo "# Project Rules (MUST follow)" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Implementation Plan\n" >> "$PROMPT"
cat "$PLAN_FILE" >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << 'EXEC_INSTRUCTIONS' >> "$PROMPT"
Implement the above plan exactly as specified. Follow these rules:

1. Implement all steps in the order specified
2. Follow the project conventions in the Project Rules strictly
3. Add all planned tests
4. Run tests after implementation to verify correctness
5. Do not deviate from the plan — implement exactly what is specified
6. Do not add extra features, refactoring, or improvements beyond the plan
EXEC_INSTRUCTIONS

codex - < "$PROMPT"
rm -f "$PROMPT"
```

### 5-2. 実装結果の検証（並列エージェント）

実装完了後、2つのエージェントを **同一メッセージで並列起動** する:

**変更内容の確認エージェント:**
```
description: "implementation diff analyzer"
prompt: |
  実装が完了しました。変更内容を確認してください:

  1. `git status` で変更ファイル一覧を取得
  2. `git diff` で全差分を確認
  3. `.claude/plan.md` を Read tool で読み、プランと実装の差異を確認
  4. 以下の観点でレポートを返す:
     - プランの全ステップが実装されているか
     - プランにない余分な変更がないか
     - 明らかなバグや問題がないか

  結果を以下の形式で返す:
  ## Implementation Check
  - Plan coverage: <N>/<M> steps implemented
  - Extra changes: Yes/No (details if yes)
  - Issues found: <list or "None">
```

**テスト実行エージェント:**
```
description: "test runner agent"
prompt: |
  実装が完了しました。プロジェクトのテストを実行してください:

  1. プロジェクトの CLAUDE.md を読んでテストコマンドを確認
  2. 変更ファイルのパスから backend/frontend を判定
  3. 該当するテストを実行:
     - Backend: `cd backend && pytest` (or project-specific command)
     - Frontend: `pnpm -C frontend run type-check && pnpm -C frontend run lint && pnpm -C frontend run test:unit`
  4. テスト結果を返す

  結果を以下の形式で返す:
  ## Test Results
  - Backend: PASS / FAIL / SKIP (details if fail)
  - Frontend: PASS / FAIL / SKIP (details if fail)
  - Total: <N> passed, <M> failed
```

### 5-3. 結果の統合と報告

並列エージェントの結果を統合して表示:

```
=== Codex Plan: Implementation Complete ===

Review rounds: <N>
Files changed: <N>

## Implementation Check
<diff analyzer の結果>

## Test Results
<test runner の結果>

## Next Steps
- 変更内容を確認してください
- 問題なければ `/commit-push` でコミット＆プッシュ
- PR作成は `/create-pr` で実行できます
```

### 5-4. クリーンアップ

```bash
rm -f .claude/plan.md
```

---

## Critical Constraints

- **Plan Mode 中はコードを変更しない** — Phase 4 のユーザー承認前に実装を開始しない
- **レビューは最大 5 ラウンド** — 無限ループ防止
- **ユーザー承認は必須** — レビュー LGTM だけでは実装に進まない
- **コンテキスト管理: 各フェーズ境界で 80% チェック**
- **実装はサブエージェントに委譲** — メインCCは実装しない、検証のみ行う
- **テスト失敗時はユーザーに報告** — 自動修正はしない（実装結果を尊重し、ユーザー判断を仰ぐ）
- **プラン修正はサブエージェントに委譲** — メインコンテキストの消費を最小限に抑える

---

## Red Flags - Never Do This

- **ユーザー承認なしで Phase 5 に進まない**
- **レビューの出力を読まずに「LGTM」と判定しない**
- **codex 使用時は `codex` / `codex review` のプロンプトに CLAUDE.md を含めずに実行しない**
- **プラン修正時にコードを変更しない（プランファイルのみ編集）**
- **テスト未実行で完了報告しない**
- **検証エージェントの結果を無視しない**
