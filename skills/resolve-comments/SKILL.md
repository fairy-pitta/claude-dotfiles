# Resolve PR Review Comments

Automatically resolve all addressed review threads on the current PR.

PR/Branch: $ARGUMENTS (optional)

## Scope

This resolves **code review threads** (comments on specific lines).
Does NOT affect general PR conversation comments.

## Process

1. **Get PR and thread information**
   ```bash
   gh pr view --json id,reviewThreads
   ```

2. **Identify unresolved threads**
   ```bash
   gh pr view --json reviewThreads --jq '
     .reviewThreads[]
     | select(.isResolved == false)
     | {id: .id, path: .path, line: .line}
   '
   ```

3. **Resolve each thread via GraphQL**
   ```bash
   gh api graphql -f query='
     mutation($threadId: ID!) {
       resolveReviewThread(input: {threadId: $threadId}) {
         thread {
           id
           isResolved
         }
       }
     }
   ' -f threadId="$THREAD_ID"
   ```

4. **Report results**
   - List each resolved thread
   - Confirm resolution status

## Output

```markdown
# Resolved Review Threads

## Results
| File | Line | Status |
|------|------|--------|
| `path/file.ts` | 42 | ✅ Resolved |
| `path/other.ts` | 15 | ✅ Resolved |

## Summary
- Threads resolved: [count]
- Threads failed: [count] (if any)

## Next Steps
- Update PR description if needed
- Request re-review
```

## Notes

- Only resolve threads after fixes are implemented and pushed
- Verify fixes are correct before resolving
- Some teams prefer manual resolution for accountability
