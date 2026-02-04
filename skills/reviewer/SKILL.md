---
name: reviewer
description: PR inline code review - posts individual review comments directly on GitHub PR diff, each on the exact code line
---

# PR Inline Reviewer

Perform a code review and **post each comment directly on the PR as an inline review comment** on the corresponding code line using `gh api`.

**Core principle:** Review the code, then post each finding as an individual inline comment on the PR diff — not as one big summary comment.

**Announce at start:** "I'm using the reviewer skill to review and post inline comments on the PR."

## Language Adaptation

**IMPORTANT: Automatically detect and adapt to the project's primary language.**

**Detection method:**
1. Check CLAUDE.md for language indicators
2. Check user's message language
3. Check recent commit messages language
4. Default to English if unclear

**Language-specific formatting:**

**Japanese:**
- Titles: 【要改善】、【必須修正】、【任意】、【確認依頼】
- Summary labels: 修正案、改善案、提案
- Polite forms: ください、お願いします

**English:**
- Titles: [Required Fix], [Improvement Needed], [Optional], [Please Confirm]
- Summary labels: Fix suggestion, Improvement suggestion, Proposal
- Professional tone: please, should, recommended

## Comment Format

Every review comment MUST follow this format:

```
_<category>_ | _<severity>_

**<title>**

<detailed explanation>

<details>
<summary>icon 修正案 / 改善案 / 提案</summary>

```diff
<code diff showing before/after>
```
</details>
```

### Severity Indicators

- **🔴 Critical** - Must fix before merge (security, data loss, crashes)
- **🟠 Major** - Should fix, impacts functionality (performance, architecture violations, type safety)
- **🟡 Minor** - Nice to have improvements (refactoring, minor optimizations)
- **🔵 Trivial** - Code style/cleanup (unused imports, formatting)

### Category Labels

- `_⚠️ Potential issue_` - Logic/design problems, bugs, incorrect implementations
- `_🧹 Nitpick_` - Code quality, style, cleanup suggestions
- `_🛠️ Refactor suggestion_` - Architecture improvements, pattern recommendations

## Review Focus Areas

Check changed files for:
1. **Type Safety** - Missing type hints, `Any` usage, type inconsistencies across layers
2. **Architecture Compliance** - Layer dependency violations, feature inter-dependencies (check CLAUDE.md)
3. **Error Handling** - Missing validation, uncaught exceptions, error message leaks
4. **Performance** - N+1 queries, O(N*M) in templates, redundant awaits
5. **Code Quality** - DRY violations, unused code, dead code, comment accuracy
6. **Accessibility** - Missing ARIA attributes, semantic HTML issues (for frontend)

## Review Process

### Step 1: Identify PR and Get Metadata

```bash
# Find the PR for the current branch
BRANCH=$(git branch --show-current)
gh pr list --head "$BRANCH" --state open --json number,title,url

# Get the latest commit SHA
COMMIT_SHA=$(gh pr view <PR_NUMBER> --json headRefOid --jq '.headRefOid')

# Get changed files
gh pr diff <PR_NUMBER> --name-only
# or
git diff --name-only origin/<base_branch>...HEAD
```

If no PR exists, inform the user and stop.

### Step 2: Review the Code

1. Get the cumulative diff: `git diff origin/<base_branch>...HEAD`
2. Read each changed file fully to understand context
3. Check against CLAUDE.md rules and the Review Focus Areas above
4. Collect all findings with their target file and line number

### Step 3: Calculate Diff Positions

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

### Step 4: Post Inline Comments

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
- `body`: The review comment in markdown (use the Comment Format above)
- `commit_id`: The HEAD commit SHA of the PR
- `path`: Relative file path from repo root (e.g., `frontend/src/components/Foo.vue`)
- `position`: The calculated position in the diff (see Step 3)

**For files NOT in the diff** (e.g., pointing out that a constant in another file became unused):
Post as a general PR comment instead:

```bash
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
  --method POST -f body="<comment body>"
```

### Step 5: Post Summary Comment

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

### Getting Owner/Repo

```bash
# Extract from git remote
gh repo view --json nameWithOwner --jq '.nameWithOwner'
# Returns: "owner/repo"
```

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

Before posting, you can verify a position is correct by checking what line it maps to:
1. Find the file's first `@@` in the numbered diff output
2. Add the position to get the target diff line number
3. Confirm that line contains the code you want to comment on

### Handling Errors

If `gh api` returns a 422 error with "position is not valid", it means:
- The calculated position doesn't fall within a diff hunk
- The line you're targeting is not part of the changed diff
- Solution: Either recalculate the position or post as a general PR comment instead

## Red Flags - Never Do This

- **Never post all comments as a single summary** — each finding must be an individual inline comment on the specific code line
- **Never guess positions** — always calculate from the actual diff output
- **Never skip the diff position calculation** — using file line numbers directly will fail
- **Never post comments without severity and category indicators**
- **Never post comments without actionable code diff suggestions**
- **Never post on lines outside the diff** — use general PR comments for those

---

**Remember:** The power of this skill is that each comment appears directly on the code line in the PR diff view, making it easy for developers to see exactly what needs attention and where.
