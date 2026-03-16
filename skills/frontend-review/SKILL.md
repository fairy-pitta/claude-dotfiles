---
name: frontend-review
description: Frontend code review — Vue 3 + TypeScript + FSD + TanStack Queryの観点で5並列レビュー（デフォルト: CC Agent、--codex で codex CLI）
---

# Frontend Review（5並列レビュー）

Vue 3 + TypeScript + FSD (Feature-Sliced Design) のフロントエンドコードを5つのチェックリストで並列レビューする。

**Announce at start:** "frontend-review スキルで5並列レビューを開始します。"

## エンジン選択

`$ARGUMENTS` に `--codex` が含まれる場合は codex CLI を使用する。それ以外は **Claude Code Agent（デフォルト）** を使用する。

```
USE_CODEX = "--codex" in $ARGUMENTS
```

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^frontend/"
```

変更ファイルが0件の場合は報告して終了。

### 2. 5並列レビュー実行

5つのチェックリストで **並列実行** する。

| # | Category | Checklist |
|---|----------|-----------|
| 1 | FSD Architecture + Dead Code | `frontend-coderabbit/checklists/fsd-architecture.md` |
| 2 | Type Safety + State Mgmt | `frontend-coderabbit/checklists/type-state.md` |
| 3 | Vue Patterns + Perf + A11y | `frontend-coderabbit/checklists/error-vue.md` |
| 4 | Query + Error + Security | `frontend-coderabbit/checklists/tanstack-security.md` |
| 5 | Test + Accounting + Naming | `frontend-coderabbit/checklists/test-quality.md` |

### 2-A: Claude Code Agent（デフォルト）

**5つの Agent tool を単一メッセージで並列起動する。**

各 Agent に以下を渡す:

```
description: "frontend review: <category>"
prompt: |
  あなたはフロントエンドコードレビューのサブエージェントです。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. チェックリストファイルを読む: ~/.claude/skills/frontend-coderabbit/checklists/<category>.md
  3. コード例ファイルを読む: ~/.claude/skills/frontend-coderabbit/references/code-examples.md
  4. 以下のコマンドで差分を取得:
     git diff origin/dev...HEAD -- frontend/
  5. チェックリストに沿って差分をレビューする

  出力フォーマット:
  | # | File:Line | Severity (🔴/🟠/🟡/🔵) | Checklist ID | Issue |

  各 finding: category + severity + title + explanation + suggested diff.
  指摘なしの場合: "No findings."
```

5つの Agent を **同時に起動** すること（単一メッセージに5つの Agent tool call）。

### 2-B: codex CLI（--codex 指定時）

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
    echo -e "\n---\n# Git diff (changes to review)\n"
    git diff origin/dev...HEAD -- frontend/
  } > "$PROMPT"
  codex review - < "$PROMPT" > "$RESULTS_DIR/${cat}.txt" 2>&1 &
done

wait
```

### 3. 結果の収集・マージ

**2-A の場合:** 各 Agent の返り値を収集する。
**2-B の場合:**

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
- レビューを直列実行（必ず並列）
- コードdiffなしに修正案を提示
