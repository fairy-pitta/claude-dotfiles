---
name: push
description: Push the current branch to the remote after verifying branch safety and checking for uncommitted changes.
---

# Push

Push the current branch to remote.

## Process

1. Verify current branch (abort if on main/master)
2. Check for uncommitted changes
   - If there are staged/unstaged changes: warn and ask whether to commit first
3. Push to remote

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Safety check
if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
  echo "ERROR: Cannot push directly to $BRANCH"
  exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "WARNING: Uncommitted changes detected"
  git status --short
  # Ask user whether to commit first or push anyway
fi

# Push
git push origin "$BRANCH" 2>&1

# Report result
echo "Pushed to origin/$BRANCH"
git log --oneline -1
```

## If push is rejected

If the remote has new commits:

```bash
git pull --rebase origin "$BRANCH" && git push origin "$BRANCH"
```

## Output

Report: branch name, commit hash, and push result (success/failure).
