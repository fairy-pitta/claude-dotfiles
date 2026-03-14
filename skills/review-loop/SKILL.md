---
name: review-loop
description: backend-review / frontend-review の codex 並列レビューを繰り返し、全指摘を解消するまでループ
---

# Review Loop

backend / frontend のチェックリストを codex review で並列実行し、指摘箇所を全て解消するまでループするスキル。

## Process

### 0. レビュー対象の判定

```bash
git diff --name-only origin/dev...HEAD
```

| 変更ファイル     | レビュー対象 |
| ---------------- | ------------ |
| `backend/` のみ  | backend 5並列 |
| `frontend/` のみ | frontend 5並列 |
| 両方             | 両方 最大10並列 |

### 1. codex review 並列実行

チェックリストを codex review に渡して Bash バックグラウンドジョブで同時実行する。

```bash
SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_MD="$(pwd)/CLAUDE.md"
RESULTS_DIR=$(mktemp -d /tmp/review-loop.XXXXXX)

# Backend (HAS_BACKEND の場合)
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
  } > "$PROMPT"
  codex review --base dev - < "$PROMPT" > "$RESULTS_DIR/be-${cat}.txt" 2>&1 &
done

# Frontend (HAS_FRONTEND の場合)
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
  } > "$PROMPT"
  codex review --base dev - < "$PROMPT" > "$RESULTS_DIR/fe-${cat}.txt" 2>&1 &
done

wait

# 結果収集
for f in "$RESULTS_DIR"/*.txt; do
  [[ "$(basename "$f")" == prompt-* ]] && continue
  echo "=== $(basename "$f" .txt) ==="
  cat "$f"
  echo
done
rm -rf "$RESULTS_DIR"
```

レビュー結果を確認し、指摘事項を収集する。

### 2. 指摘事項の分析

全結果を集約・重複排除し、以下を抽出：

- 🔴 Critical（必須修正）
- 🟠 Major（要修正）
- 🟡 Minor（改善推奨）
- 🔵 Trivial（任意）

指摘がない場合は**完了**として終了。

### 3. 指摘事項の修正

優先度順（Critical → Major → Minor → Trivial）に修正を実施：

1. 各指摘の修正案（diff）を参照
2. コードを修正
3. 修正内容を簡潔に記録

**修正時の注意:**

- Critical/Majorは必ず修正
- Minor/Trivialは可能な限り修正（明らかに不要な場合はスキップ可）
- 修正案がある場合はそれに従う
- 修正案がない場合は指摘内容に基づき適切に対応
- 修正が終わったら、リンターやテストを全て実行し、デグレをしていないことを都度確かめること。

### 4. 再レビュー

修正完了後、再度同じ codex review 並列実行を行う。

### 5. ループ判定

- 指摘が**0件**の場合 → **完了**
- 指摘が残っている場合 → ステップ3に戻る

### 6. 最大ループ回数

無限ループ防止のため、**最大20回**のループで終了。
20回を超えても指摘が残る場合は、残りの指摘事項を報告して終了。

## Output Format

### 各ループの報告

```markdown
## Loop <N> Results

**レビュー指摘数（カテゴリ別）:**

| Category | 🔴 | 🟠 | 🟡 | 🔵 | 計 |
|----------|-----|-----|-----|-----|-----|
| architecture | <N> | <N> | <N> | <N> | <N> |
| type-safety | <N> | <N> | <N> | <N> | <N> |
| ... | ... | ... | ... | ... | ... |

**修正した項目:**

1. <ファイル名>: <修正内容>
2. ...

**次のアクション:** 再レビュー実行 / 完了
```

### 完了時の報告

```markdown
## Review Loop Complete

**総ループ回数:** <N>
**修正した指摘総数:** <N>

**修正サマリー:**

- <カテゴリ>: <N>件修正
- ...

全ての指摘事項が解消されました。
```

## Critical Constraints

- **codexレビューは必ず並列実行**（直列禁止）
- 修正はレビュー指摘に基づくこと
- 新しい問題を導入しないよう注意
- 最大20回のループで終了
- 各ループの結果を明確に報告

## Usage

```
/review-loop
```

引数なしで実行。現在のブランチの変更ファイルをレビュー対象とする。
