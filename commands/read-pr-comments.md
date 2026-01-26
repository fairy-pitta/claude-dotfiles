# Read Unresolved PR Comments

Retrieve and analyze unresolved review comments from the current PR.

Branch/PR: $ARGUMENTS (optional, defaults to current branch)

## Process

1. **Get PR information**
   ```bash
   # If PR number provided
   gh pr view $ARGUMENTS --json number,title,reviewThreads

   # If on branch, find associated PR
   gh pr view --json number,title,reviewThreads
   ```

2. **Extract unresolved threads**
   ```bash
   gh pr view --json reviewThreads --jq '
     .reviewThreads[]
     | select(.isResolved == false)
     | {
         path: .path,
         line: .line,
         author: .comments[0].author.login,
         body: .comments[0].body,
         createdAt: .comments[0].createdAt
       }
   '
   ```

3. **Analyze each comment**

   **Explore Agent:**
   - Understand the context of each comment
   - Locate the relevant code
   - Identify the issue being raised

   **Plan Agent:**
   - Create remediation strategy for each comment
   - Prioritize by severity/complexity
   - Group related comments

4. **Generate correction plan**

## Output Format

```markdown
# Unresolved Review Comments

## Summary
- Total unresolved: [count]
- Files affected: [list]

## Comments

### Comment 1
- **File:** `path/to/file.ts:123`
- **Author:** @username
- **Feedback:** [comment content]
- **Analysis:** [what needs to change]
- **Fix Strategy:** [how to fix]

### Comment 2
...

## Recommended Fix Order
1. [Comment X] - [reason for priority]
2. [Comment Y] - [reason]

## Next Steps
Use `/fix-review [branch]` to address these comments
```
