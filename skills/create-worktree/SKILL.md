---
name: create-worktree
description: Create an isolated git worktree for a specified branch after fetching the latest remote state.
---

# Create Git Worktree

Create an isolated git worktree for the specified branch: $ARGUMENTS

## Process

1. **Fetch latest from remote**
   ```bash
   git fetch origin
   ```

2. **Determine worktree base directory**
   - If `.git-worktrees/` exists in the current directory, use it
   - Otherwise, fall back to `.claude/worktrees/`
   ```bash
   if [ -d ".git-worktrees" ]; then
     WORKTREE_BASE=".git-worktrees"
   else
     WORKTREE_BASE=".claude/worktrees"
   fi
   mkdir -p "$WORKTREE_BASE"
   ```

3. **Create worktree**
   - Convert branch name (replace `/` with `-`)
   - Create worktree in `$WORKTREE_BASE/[branch-name]`
   ```bash
   BRANCH_NAME=$(echo "$ARGUMENTS" | tr '/' '-')
   git worktree add "$WORKTREE_BASE/$BRANCH_NAME" -b $ARGUMENTS origin/main
   ```

4. **Setup environment**
   ```bash
   cd "$WORKTREE_BASE/$BRANCH_NAME"
   # Copy environment files if they exist
   ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || echo "../..")
   cp "$ROOT_DIR/.env" .env 2>/dev/null || true
   cp "$ROOT_DIR/.env.local" .env.local 2>/dev/null || true
   # Install dependencies
   npm install 2>/dev/null || yarn install 2>/dev/null || true
   ```

5. **Report location and prompt directory change**
   - Print the worktree absolute path
   - Confirm setup completion
   - Prompt the user to change directory:
     ```
     Worktreeの準備ができました。以下を実行してディレクトリを移動してください:
     !cd <worktree-absolute-path>
     ```

## Reuse Existing

If worktree already exists:
```bash
cd "$WORKTREE_BASE/$BRANCH_NAME"
git pull origin main
```

## Cleanup (when done)

```bash
git worktree remove "$WORKTREE_BASE/$BRANCH_NAME"
```
