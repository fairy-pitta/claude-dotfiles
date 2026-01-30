# Execute GitHub Issue

Execute the task defined in GitHub Issue: $ARGUMENTS

## Preparation

1. **Read the issue**
   ```bash
   gh issue view $ARGUMENTS
   ```
   - Understand requirements and implementation plan
   - Note any images or attachments

2. **Create isolated worktree**
   - Use `/create-worktree` with appropriate branch name
   - Branch name should relate to the issue (e.g., `issue-123-feature-name`)
   ```bash
   BRANCH="issue-$ARGUMENTS"
   ```

3. **Navigate to worktree**
   ```bash
   cd .git-worktrees/$BRANCH
   pwd  # Verify location
   ```

## Execution

4. **Implement the task**
   - Follow the implementation plan from the issue
   - Execute tasks sequentially using sub-agents
   - Test each change before proceeding

5. **Commit changes**
   - Use `/commit-push` to commit with meaningful messages
   - Reference the issue number in commits

6. **Create Pull Request**
   - Use `/create-pr` to create PR
   - Link to the issue with `Closes #$ARGUMENTS`

## Critical Constraints

- ALL work must happen within the created worktree
- Verify location with `pwd` before making changes
- Do NOT modify code outside the worktree
- Follow the implementation plan strictly

## Output

- Report PR URL when complete
- Summarize changes made
