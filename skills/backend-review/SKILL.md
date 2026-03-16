---
name: backend-review
description: Backend code review — Django/DDD/Clean Architectureの観点で5並列codexレビュー
---

# Backend Review（codex 並列レビュー）

Django + Clean Architecture/DDDのバックエンドコードを5つのチェックリストで並列レビューする。

**Announce at start:** "backend-review スキルで5並列codexレビューを開始します。"

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^backend/"
```

変更ファイルが0件の場合は報告して終了。

### 2. 5並列codexレビュー実行

5つのチェックリストを codex review に渡して **Bash backgroundジョブで同時実行** する。

| # | Category | Checklist |
|---|----------|-----------|
| 1 | architecture | `backend-coderabbit/checklists/architecture.md` |
| 2 | type-safety | `backend-coderabbit/checklists/type-safety.md` |
| 3 | db-performance | `backend-coderabbit/checklists/db-performance.md` |
| 4 | test-quality | `backend-coderabbit/checklists/test-quality.md` |
| 5 | security-errors | `backend-coderabbit/checklists/security-errors.md` |

```bash
SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_MD="$(pwd)/CLAUDE.md"
RESULTS_DIR=$(mktemp -d /tmp/backend-review.XXXXXX)

for cat in architecture type-safety db-performance test-quality security-errors; do
  PROMPT="$RESULTS_DIR/prompt-${cat}.txt"
  {
    echo "# Project Rules"
    [ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD"
    echo -e "\n---\n# Checklist"
    cat "$SKILLS_DIR/backend-coderabbit/checklists/${cat}.md"
    echo -e "\n---\n# Code Examples"
    cat "$SKILLS_DIR/backend-coderabbit/references/code-examples.md"
    echo -e "\n---"
    cat << 'INST'
Backend code review. Check all changed backend/ files against the checklist.
Report findings only. No code modifications.

Output per finding:
| # | File:Line | Severity (🔴/🟠/🟡/🔵) | Checklist ID | Issue |

Then for each finding: category + severity + title + explanation + suggested diff.
If no issues found, output: "No findings."
INST
    echo -e "\n---\n# Git diff (changes to review)\n"
    git diff origin/dev...HEAD -- backend/
  } > "$PROMPT"
  codex review - < "$PROMPT" > "$RESULTS_DIR/${cat}.txt" 2>&1 &
done

wait
```

### 3. 結果の収集・マージ

```bash
for cat in architecture type-safety db-performance test-quality security-errors; do
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
| 1 | Architecture | <N> |
| 2 | Type Safety | <N> |
| 3 | DB Performance | <N> |
| 4 | Test Quality | <N> |
| 5 | Security + Errors | <N> |

🔴 <N> / 🟠 <N> / 🟡 <N> / 🔵 <N>
```

---

## Red Flags

- チェックリスト項目をスキップ
- 修正案なしのフィードバック
- codexレビューを直列実行（必ず並列）
- コードdiffなしに修正案を提示
