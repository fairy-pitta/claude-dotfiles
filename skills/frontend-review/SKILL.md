---
name: frontend-review
description: Frontend code review — Vue 3 + TypeScript + FSD + TanStack Queryの観点で5並列codexレビュー
---

# Frontend Review（codex 並列レビュー）

Vue 3 + TypeScript + FSD (Feature-Sliced Design) のフロントエンドコードを5つのチェックリストで並列レビューする。

**Announce at start:** "frontend-review スキルで5並列codexレビューを開始します。"

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^frontend/"
```

変更ファイルが0件の場合は報告して終了。

### 2. 5並列codexレビュー実行

5つのチェックリストを codex review に渡して **Bash backgroundジョブで同時実行** する。

| # | Category | Checklist |
|---|----------|-----------|
| 1 | FSD Architecture + Dead Code | `frontend-coderabbit/checklists/fsd-architecture.md` |
| 2 | Type Safety + State Mgmt | `frontend-coderabbit/checklists/type-state.md` |
| 3 | Vue Patterns + Perf + A11y | `frontend-coderabbit/checklists/error-vue.md` |
| 4 | Query + Error + Security | `frontend-coderabbit/checklists/tanstack-security.md` |
| 5 | Test + Accounting + Naming | `frontend-coderabbit/checklists/test-quality.md` |

```bash
SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_MD="$(pwd)/CLAUDE.md"
RESULTS_DIR=$(mktemp -d /tmp/frontend-review.XXXXXX)

for cat in fsd-architecture type-state error-vue tanstack-security test-quality; do
  PROMPT="$RESULTS_DIR/prompt-${cat}.txt"
  {
    echo "# Project Rules"
    [ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD"
    echo -e "\n---\n# Checklist"
    cat "$SKILLS_DIR/frontend-coderabbit/checklists/${cat}.md"
    echo -e "\n---\n# Code Examples"
    cat "$SKILLS_DIR/frontend-coderabbit/references/code-examples.md"
    echo -e "\n---"
    cat << 'INST'
Frontend code review. Check all changed frontend/ files against the checklist.
Report findings only. No code modifications.

Output per finding:
| # | File:Line | Severity (🔴/🟠/🟡/🔵) | Checklist ID | Issue |

Then for each finding: category + severity + title + explanation + suggested diff.
If no issues found, output: "No findings."
INST
  } > "$PROMPT"
  codex review --base dev - < "$PROMPT" > "$RESULTS_DIR/${cat}.txt" 2>&1 &
done

wait
```

### 3. 結果の収集・マージ

```bash
for cat in fsd-architecture type-state error-vue tanstack-security test-quality; do
  echo "=== ${cat} ==="
  cat "$RESULTS_DIR/${cat}.txt"
  echo
done
rm -rf "$RESULTS_DIR"
```

1. **重複排除** — 同一ファイル・同一行は重要度の高い方を残す
2. **Severity順ソート** — 🔴 → 🟠 → 🟡 → 🔵

### 4. Summary

```markdown
## Review Summary

**Findings: <N>**

| # | Category | Findings |
|---|----------|----------|
| 1 | FSD Architecture + Dead Code | <N> |
| 2 | Type Safety + State Mgmt | <N> |
| 3 | Vue Patterns + Perf + A11y | <N> |
| 4 | Query + Error + Security | <N> |
| 5 | Test + Accounting + Naming | <N> |

🔴 <N> / 🟠 <N> / 🟡 <N> / 🔵 <N>
```

---

## Red Flags

- チェックリスト項目をスキップ
- 修正案なしのフィードバック
- codexレビューを直列実行（必ず並列）
- コードdiffなしに修正案を提示
