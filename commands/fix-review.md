# Fix Review Points

Address unresolved review comments on branch: $ARGUMENTS

## Setup

1. **Create/access worktree**
   - Use `/create-worktree $ARGUMENTS`
   ```bash
   cd .git-worktrees/$(echo "$ARGUMENTS" | tr '/' '-')
   pwd  # Verify location
   ```

## Process

2. **Analyze unresolved comments**
   ```bash
   gh pr view --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false) | {path: .path, line: .line, body: .comments[0].body}'
   ```

3. **Plan fixes**
   - Use Explore sub-agent to understand each issue
   - Use Plan sub-agent to create fix strategy

4. **Execute fixes**
   - Address each comment sequentially
   - Use general-purpose sub-agent for implementation
   - Test each fix

5. **Commit and push**
   - Use `/commit-push` with descriptive message
   - Reference review comments in commit

6. **Resolve threads**
   ```bash
   # Resolve via GitHub UI or API
   gh api graphql -f query='...'
   ```

7. **Update PR**
   - Update PR description with fix summary
   - Request re-review
   ```bash
   gh pr comment --body "Review feedback addressed. Please re-review."
   ```

## Critical Constraints

- ALL work within the worktree only
- Verify with `pwd` before changes
- Do not modify outside the worktree

## Output

- List of fixed issues
- Updated PR description
- Re-review requested
