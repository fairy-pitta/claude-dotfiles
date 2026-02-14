---
name: reviewer
description: PR inline code review - runs coderabbit-review then posts each comment directly on the GitHub PR diff as individual inline comments
---

# PR Inline Reviewer

Run a `coderabbit-review` style code review, then **post each finding directly on the PR as an individual inline comment** on the corresponding code line using `gh api`.

**Core principle:** Leverage the coderabbit-review skill for thorough analysis, then deliver results as inline PR comments — not as one big summary comment.

**Announce at start:** "reviewer スキルでレビューしてインラインコメントを投稿します"

## Workflow Overview

```
Step 1: Identify PR and get metadata (PR number, commit SHA, owner/repo)
Step 2: Perform code review using coderabbit-review methodology
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

## Step 2: Perform Code Review

**Use the coderabbit-review methodology** for the review itself. This means:

1. Get the diff: `git diff origin/<base_branch>...HEAD`
2. Read each changed file to understand context
3. Apply the **5-pass grouped review** (Groups A-E, 27 review points) from coderabbit-review:
   - **Group A:** Type Safety (Any type, layer type consistency, FE annotations, etc.)
   - **Group B:** Architecture & Placement (feature dependencies, layer violations, Result type, etc.)
   - **Group C:** Error Handling & Security (validation, API error normalization, etc.)
   - **Group D:** Performance (N+1 queries, O(N*M) in templates, redundant awaits)
   - **Group E:** Code Quality & DRY (unused code, dead code, v-for keys, comment accuracy, etc.)
4. Check against CLAUDE.md project rules
5. Filter out obvious/trivial findings (e.g., things that are intentional or self-evident)

For each finding, record:
- The target file path
- The target line number in the file
- Brief description of the issue

## Step 3: Present Findings for User Approval

**CRITICAL: Do NOT post comments until user approves.**

Present findings as a table in Japanese:

```markdown
## 指摘予定リスト

| # | 重要度 | ファイル | 行 | 内容 |
|---|--------|----------|-----|------|
| 1 | Medium | `path/to/file.ts` | 42 | 簡潔な説明 |
| 2 | Low | `path/to/other.vue` | 100 | 簡潔な説明 |
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

**Example:**
```
 250 | diff --git a/src/foo.ts b/src/foo.ts
 251 | index abc..def 100644
 252 | --- a/src/foo.ts
 253 | +++ b/src/foo.ts
 254 | @@ -9,16 +9,65 @@          <-- First @@ for this file
 255 |  import { something }        <-- position = 255 - 254 = 1
 256 | +const newCode = true        <-- position = 256 - 254 = 2
 ...
 314 | +  return result             <-- position = 314 - 254 = 60
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

**Parameters:**
- `body`: The review comment (see Comment Format below)
- `commit_id`: The HEAD commit SHA of the PR
- `path`: Relative file path from repo root (e.g., `frontend/src/components/Foo.vue`)
- `position`: The calculated position in the diff (see Step 4)

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

**Good example:**
```
[エラーハンドリング - Medium] エラーメッセージがハードコード

`'登録に失敗しました'` が定数化されてない

```diff
-  submitError.value = e instanceof Error ? e.message : '登録に失敗しました'
+  submitError.value = e instanceof Error ? e.message : VALIDATION_MESSAGES.REGISTRATION_FAILED
```
```

**Bad example:**
```
## [エラーハンドリング - Medium] エラーメッセージがハードコードされてるね

ここの `'登録に失敗しました'` がベタ書きになってるね。CLAUDE.md的には `messageConstants.ts` に定数化した方がいいかも。今の規模なら問題ないけど、将来的には統一しておくと安心かな。
```

## Practical Tips

### JSON Escaping in Comment Body

When the comment body contains special characters (quotes, backticks, newlines), use `--input -` with a heredoc and proper JSON:

```bash
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments \
  --method POST --input - <<'JSONEOF'
{
  "body": "line1\nline2\n\n```diff\n- old\n+ new\n```",
  "commit_id": "abc123",
  "path": "src/foo.ts",
  "position": 42
}
JSONEOF
```

**Tips for JSON body construction:**
- Newlines in the body must be `\n`
- Quotes must be escaped as `\"`
- Backticks do not need escaping in JSON strings
- Use `\n\n` for paragraph breaks

### Verifying Position Accuracy

Before posting, verify a position is correct by checking what line it maps to:
1. Find the file's first `@@` in the numbered diff output
2. Add the position to get the target diff line number
3. Confirm that line contains the code you want to comment on

### Handling Errors

If `gh api` returns a 422 error with "position is not valid":
- The calculated position doesn't fall within a diff hunk
- The line you're targeting is not part of the changed diff
- Solution: Recalculate the position or post as a general PR comment instead

If `gh api` returns a 422 error with `"subject_type" is not a permitted key`:
- Do NOT use `line`, `side`, or `subject_type` parameters
- Use only `body`, `commit_id`, `path`, and `position`

## Red Flags - Never Do This

- **Never post comments without user approval** — always present the list first and wait
- **Never post all comments as a single summary** — each finding must be an individual inline comment on the specific code line
- **Never guess positions** — always calculate from the actual diff output
- **Never skip the diff position calculation** — using file line numbers directly will fail
- **Never use the `line` or `subject_type` API parameters** — use `position` only
- **Never add fluff or excuses to comments** — keep them direct and concise
- **Never post on lines outside the diff** — use general PR comments for those
- **Never skip the coderabbit-review 5-pass review** — this skill's value is combining thorough review with precise PR delivery

---

**Remember:** This skill combines the thoroughness of coderabbit-review with the precision of inline PR comments. Each comment appears directly on the code line in the PR diff view, making it easy for developers to see exactly what needs attention and where.
