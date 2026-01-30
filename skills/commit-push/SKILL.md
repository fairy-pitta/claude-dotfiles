# Commit and Push Changes

Commit and push the current changes with strategic git practices.

Context: $ARGUMENTS

## Strategy Selection

### Strategy A: Squash/Amend (Default)
Use when changes relate to the same feature/theme:
```bash
git add -A
git commit --amend --no-edit
git push --force-with-lease
```

### Strategy B: New Commit
Use for independent changes or when splitting improves clarity:
```bash
git add -A
git commit -m "type: description"
git push
```

### Strategy C: Interactive Rebase
Use to reorganize multiple commits:
```bash
git rebase -i origin/main
# Squash/reorder as needed
git push --force-with-lease
```

## Commit Message Format

```
type: subject (max 50 chars)

[optional body - explain "why" not "what"]

[optional footer - issue references]
```

**Types:** feat, fix, refactor, test, docs, chore, style, perf

## Critical Rules

- NEVER commit directly to main/master branch
- Remove unnecessary code comments before committing
- Each commit should be atomic and meaningful
- Verify changes with `git diff --staged` before committing

## Process

1. Check current branch (must not be default branch)
2. Review staged changes
3. Select appropriate strategy based on context
4. Create commit with conventional message
5. Push to remote
6. Report success with commit hash
