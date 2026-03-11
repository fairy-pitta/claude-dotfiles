---
name: create-pr
description: Create a pull request for the current branch after checking git status and staged changes.
---

# Create Pull Request

Create a pull request for the current changes.

Context: $ARGUMENTS

## Process

1. **Check current state**
   ```bash
   git status
   git diff --staged
   git log --oneline -5
   ```

2. **Check for PR template**
   ```bash
   cat .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || echo "No template found"
   ```

3. **Prepare PR content**

   If template exists:
   - Follow template structure exactly
   - Remove all HTML comments (`<!-- ... -->`)
   - Fill in all required sections

   If no template:
   - Use standard format below

4. **Link related issues**
   - Include `Closes #123` or `Fixes #123` in description
   - Reference related issues with `Related to #456`

5. **Create the PR**
   ```bash
   gh pr create --title "[type]: description" --body "..."
   ```

6. **Report PR URL**

## Standard PR Format (when no template)

```markdown
## Summary
[Brief description of changes]

## Changes
- Change 1
- Change 2

## Testing
- [ ] Unit tests pass
- [ ] Manual testing completed

## Related Issues
Closes #[issue-number]

## Screenshots (if UI changes)
[Add screenshots]
```

## Title Format

```
type: concise description (max 72 chars)
```

Types: feat, fix, refactor, docs, test, chore, style, perf

## Checklist Before Creating

- [ ] Changes are committed and pushed
- [ ] Branch is up to date with main
- [ ] Tests pass
- [ ] No merge conflicts
- [ ] PR title follows convention
