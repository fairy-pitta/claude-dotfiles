# Create Git Worktree

Create an isolated git worktree for the specified branch: $ARGUMENTS

## Process

1. **Fetch latest from remote**
   ```bash
   git fetch origin
   ```

2. **Create worktree directory**
   ```bash
   mkdir -p .git-worktrees
   ```

3. **Create worktree**
   - Convert branch name (replace `/` with `-`)
   - Create worktree in `.git-worktrees/[branch-name]`
   ```bash
   BRANCH_NAME=$(echo "$ARGUMENTS" | tr '/' '-')
   git worktree add .git-worktrees/$BRANCH_NAME -b $ARGUMENTS origin/main
   ```

4. **Setup environment**
   ```bash
   cd .git-worktrees/$BRANCH_NAME
   # Copy environment files if they exist
   cp ../../.env .env 2>/dev/null || true
   cp ../../.env.local .env.local 2>/dev/null || true
   # Install dependencies
   npm install 2>/dev/null || yarn install 2>/dev/null || true
   ```

5. **Report location**
   - Print the worktree path
   - Confirm setup completion

## Reuse Existing

If worktree already exists:
```bash
cd .git-worktrees/$BRANCH_NAME
git pull origin main
```

## Cleanup (when done)

```bash
git worktree remove .git-worktrees/$BRANCH_NAME
```
