# Fix Review Points (Loop)

Continuously fix unresolved PR review comments for branch: $ARGUMENTS

## Initial Setup

1. **Create/access worktree**
   - Use `/create-worktree $ARGUMENTS`
   - Navigate to worktree
   ```bash
   cd .git-worktrees/$(echo "$ARGUMENTS" | tr '/' '-')
   pwd  # Verify location
   ```

## Review Resolution Cycle

2. **Fetch unresolved comments**
   ```bash
   gh pr view --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false)'
   ```

3. **For each unresolved comment:**
   - Analyze the feedback
   - Implement the fix using sub-agent
   - Test the change
   - Commit with reference to the comment

4. **Push and resolve**
   - Use `/commit-push` to push changes
   - Resolve the review thread

5. **Update PR description**
   - Reflect fixes made
   - Add summary of changes

6. **Request re-review**
   ```bash
   gh pr comment --body "Changes addressed. Ready for re-review."
   ```

## Loop

7. **Wait and repeat**
   - Wait 5 minutes
   - Check for new unresolved comments
   - Repeat steps 2-6 until no unresolved comments remain

## Critical Constraints

- Work ONLY within the worktree
- Verify location with `pwd` before each change
- Do not modify code outside the worktree

## Completion

- All review threads resolved
- PR updated with fix summary
- Re-review requested
