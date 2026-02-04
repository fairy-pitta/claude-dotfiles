---
name: reviewer
description: PR inline code review - runs coderabbit-review then posts each comment directly on the GitHub PR diff as individual inline comments
---

# PR Inline Reviewer

Run a `coderabbit-review` style code review, then **post each finding directly on the PR as an individual inline comment** on the corresponding code line using `gh api`.

**Core principle:** Leverage the coderabbit-review skill for thorough analysis, then deliver results as inline PR comments — not as one big summary comment.

**Announce at start:** "I'm using the reviewer skill to review and post inline comments on the PR."

## Workflow Overview

```
Step 1: Identify PR and get metadata (PR number, commit SHA, owner/repo)
Step 2: Perform code review using coderabbit-review methodology
Step 3: Get numbered diff and calculate positions for each finding
Step 4: Post each finding as an inline comment via gh api
Step 5: Post a summary comment on the PR
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
4. Use the coderabbit-review **comment format** (category + severity + title + explanation + diff suggestion)
5. Check against CLAUDE.md project rules

For each finding, record:
- The comment body (in coderabbit-review format)
- The target file path
- The target line number in the file

## Step 3: Calculate Diff Positions

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

## Step 4: Post Inline Comments

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
- `body`: The review comment in coderabbit-review format (category + severity + explanation + diff)
- `commit_id`: The HEAD commit SHA of the PR
- `path`: Relative file path from repo root (e.g., `frontend/src/components/Foo.vue`)
- `position`: The calculated position in the diff (see Step 3)

**For files NOT in the diff** (e.g., pointing out that a constant in another file became unused):
Post as a general PR comment instead:

```bash
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
  --method POST -f body="<comment body>"
```

## Step 5: Post Summary Comment

After all inline comments are posted, post a summary as a general PR comment:

```bash
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
  --method POST -f body="$(cat <<'EOF'
## Review Summary

**Actionable comments posted: <N>**

### Severity Distribution
- 🔴 Critical: <N>
- 🟠 Major: <N>
- 🟡 Minor: <N>
- 🔵 Trivial: <N>

### Recommendations
1. **Must fix before merge:** [Critical/Major items]
2. **Should fix:** [Minor items]
3. **Optional:** [Trivial items]
EOF
)"
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

- **Never post all comments as a single summary** — each finding must be an individual inline comment on the specific code line
- **Never guess positions** — always calculate from the actual diff output
- **Never skip the diff position calculation** — using file line numbers directly will fail
- **Never use the `line` or `subject_type` API parameters** — use `position` only
- **Never post comments without severity and category indicators** (coderabbit-review format required)
- **Never post comments without actionable code diff suggestions**
- **Never post on lines outside the diff** — use general PR comments for those
- **Never skip the coderabbit-review 5-pass review** — this skill's value is combining thorough review with precise PR delivery

---

**Remember:** This skill combines the thoroughness of coderabbit-review with the precision of inline PR comments. Each comment appears directly on the code line in the PR diff view, making it easy for developers to see exactly what needs attention and where.
