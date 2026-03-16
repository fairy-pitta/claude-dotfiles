---
name: reviewer
description: PR inline code review — 並列レビュー後、各指摘をGitHub PRのdiffにインラインコメントとして投稿（デフォルト: CC Agent、--codex で codex CLI）
---

# PR Inline Reviewer

並列レビューし、**各指摘をPRのインラインコメントとして投稿** する。

**Announce at start:** "reviewer スキルで並列レビューしてインラインコメントを投稿します"

## エンジン選択

`$ARGUMENTS` に `--codex` が含まれる場合は codex CLI を使用する。それ以外は **Claude Code Agent（デフォルト）** を使用する。

```
USE_CODEX = "--codex" in $ARGUMENTS
```

## Workflow Overview

```
Step 1: Identify PR and get metadata (PR number, commit SHA, owner/repo)
Step 2: Perform code review using codex review 並列実行
Step 3: Present findings list to user for approval (MUST WAIT)
Step 4: After user approval, get numbered diff and calculate positions
Step 5: Post each finding as an inline comment via gh api
```

## Step 1: Identify PR and Get Metadata

```bash
# Find the PR for the current branch
BRANCH=$(git branch --show-current)
gh pr list --head "$BRANCH" --state open --json number,title,url

# Get the latest commit SHA
COMMIT_SHA=$(gh pr view <PR_NUMBER> --json headRefOid --jq '.headRefOid')

# Get owner/repo
gh repo view --json nameWithOwner --jq '.nameWithOwner'
# Returns: "owner/repo"

# Get changed files
git diff --name-only origin/<base_branch>...HEAD
```

If no PR exists, inform the user and stop.

## Step 2: 並列レビュー実行

**変更ファイルのパスを見てレビュー対象を自動選択する。**

```bash
git diff --name-only origin/<base_branch>...HEAD
```

| 変更ファイルのパス | レビュー対象 |
|---|---|
| `backend/` のみ | backend 5並列 |
| `frontend/` のみ | frontend 5並列 |
| 両方混在 | 両方 最大10並列 |
| その他（`.github/`, `CLAUDE.md` 等） | 一般的なコード品質チェック |

### 2-A: Claude Code Agent（デフォルト）

**最大10個の Agent tool を単一メッセージで並列起動する。**

各 Agent に以下を渡す:

```
description: "review: <be/fe>-<category>"
prompt: |
  あなたはコードレビューのサブエージェントです。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. チェックリストファイルを読む: ~/.claude/skills/<backend-coderabbit or frontend-coderabbit>/checklists/<category>.md
  3. コード例ファイルを読む: ~/.claude/skills/<backend-coderabbit or frontend-coderabbit>/references/code-examples.md
  4. 以下のコマンドで差分を取得:
     git diff origin/<base_branch>...HEAD -- <backend/ or frontend/>
  5. チェックリストに沿って差分をレビューする

  出力フォーマット:
  | # | File:Line | Severity (🔴/🟠/🟡/🔵) | Checklist ID | Issue |
  各 finding: category + severity + title + explanation + suggested diff.
  指摘なしの場合: "No findings."
```

全 Agent を **同時に起動** すること。

### 2-B: codex CLI（--codex 指定時）

```bash
SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_MD="$(pwd)/CLAUDE.md"
RESULTS_DIR=$(mktemp -d /tmp/reviewer.XXXXXX)

# Backend (backend/ に変更がある場合)
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
    git diff origin/<base_branch>...HEAD -- backend/
  } > "$PROMPT"
  codex review - < "$PROMPT" > "$RESULTS_DIR/be-${cat}.txt" 2>&1 &
done

# Frontend (frontend/ に変更がある場合)
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
    git diff origin/<base_branch>...HEAD -- frontend/
  } > "$PROMPT"
  codex review - < "$PROMPT" > "$RESULTS_DIR/fe-${cat}.txt" 2>&1 &
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

### 結果のマージ

全結果を集約・重複排除し、各指摘について記録:

- ファイルパス
- 行番号
- 重要度
- 簡潔な説明

## Step 3: Present Findings for User Approval

**CRITICAL: Do NOT post comments until user approves.**

Present findings as a table in Japanese:

```markdown
## 指摘予定リスト

| # | 重要度 | カテゴリ | ファイル | 行 | 内容 |
|---|--------|---------|----------|-----|------|
| 1 | Medium | architecture | `path/to/file.py` | 42 | 簡潔な説明 |
| 2 | Low | type-safety | `path/to/other.ts` | 100 | 簡潔な説明 |
...

どれを投稿するか、修正・削除したい項目はありますか？
```

Wait for user to:
- Approve all
- Remove specific items
- Modify specific items
- Discuss specific items

Only proceed to Step 4 after explicit approval.

## Step 4: Calculate Diff Positions

The GitHub API requires a `position` parameter (not a file line number) to place inline comments. The position is calculated from the diff output.

**How to calculate:**

```bash
# Get the cumulative diff with global line numbers
gh pr diff <PR_NUMBER> | awk '{printf "%4d | %s\n", NR, $0}'
```

For each file in the diff, find the **first `@@` hunk line**. The position of any target line is:

```
position = target_diff_line_number - first_@@_line_number_for_that_file
```

**IMPORTANT:**
- Only lines that appear in the diff can receive inline comments
- Both added (+), removed (-), and context lines can be commented on
- Position counting continues across multiple `@@` hunks within the same file (positions do NOT reset at each hunk)
- The first `@@` line of the file is the reference point (position 0); all subsequent lines count from there

## Step 5: Post Inline Comments

Use `gh api` to post each comment individually on the exact code line:

```bash
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments \
  --method POST --input - <<'JSONEOF'
{
  "body": "<comment body in markdown>",
  "commit_id": "<COMMIT_SHA>",
  "path": "<relative/file/path>",
  "position": <calculated_position>
}
JSONEOF
```

**For files NOT in the diff** (e.g., pointing out that a constant in another file became unused):
Post as a general PR comment instead:

```bash
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
  --method POST -f body="<comment body>"
```

## Comment Format

**Keep comments concise and direct. No fluff.**

Format:
```
[カテゴリ - 重要度] タイトル

簡潔な説明（1-2文）

```diff
- old code
+ new code
```
```

**Style rules:**
- NO `##` headers — just `[カテゴリ - 重要度]`
- NO trailing particles like 「ね」「かな」「かも」
- NO follow-up excuses like 「このままでもOK」「今の規模なら問題ない」
- NO unnecessary context like 「CLAUDE.md的には」
- Let the diff speak for itself — minimal explanation needed
- Write in Japanese

## Red Flags - Never Do This

- **Never post comments without user approval** — always present the list first and wait
- **Never post all comments as a single summary** — each finding must be an individual inline comment on the specific code line
- **Never guess positions** — always calculate from the actual diff output
- **Never skip the diff position calculation** — using file line numbers directly will fail
- **Never use the `line` or `subject_type` API parameters** — use `position` only
- **Never add fluff or excuses to comments** — keep them direct and concise
- **Never post on lines outside the diff** — use general PR comments for those
- **Never run reviews sequentially** — always launch all in parallel (Agent tools or bash background jobs)
- **Never apply backend observations to frontend files or vice versa** — always match the review checklist to the file's path
