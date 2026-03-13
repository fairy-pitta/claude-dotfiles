---
name: create-pr
description: Create a pull request for the current branch with auto-assign and labels. Then call /link-notion and /capture-ui as best-effort.
---

# Create Pull Request

Create a pull request for the current changes, then run post-creation enhancements.

Context: $ARGUMENTS

## Process

### Step 1: Check current state

```bash
git status
git diff --staged
git log --oneline -10
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BASE=$(git rev-parse --verify origin/dev >/dev/null 2>&1 && echo "dev" || echo "main")
git diff "$BASE"...HEAD --stat
```

### Step 2: Check for PR template

```bash
cat .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || echo "No template found"
```

### Step 3: Prepare PR content

If template exists:
- Follow template structure exactly
- Remove all HTML comments (`<!-- ... -->`)
- Fill in all required sections

If no template:
- Use standard format below

Include issue links:
- `Closes #123` or `Fixes #123` in description
- `Related to #456` for related issues

### Step 4: Determine labels

First, list available labels in the repository:
```bash
gh label list --limit 100
```

Then select labels based on the following rules (in priority order):

**a. From branch prefix / PR title type:**
| Prefix/Type  | Label candidates (use if exists in repo) |
|-------------|------------------------------------------|
| `feat`      | `enhancement`, `feature`                 |
| `fix`       | `bug`, `bugfix`                          |
| `refactor`  | `refactor`, `tech-debt`                  |
| `docs`      | `documentation`                          |
| `test`      | `test`, `testing`                        |
| `chore`     | `chore`, `maintenance`                   |
| `perf`      | `performance`                            |
| `style`     | `style`                                  |

**b. From changed files (auto-detect scope):**
| Changed paths             | Label candidates               |
|--------------------------|--------------------------------|
| `frontend/`, `src/components/`, `*.vue`, `*.tsx` | `frontend`    |
| `backend/`, `api/`, `*.py`  | `backend`                    |
| `infra/`, `terraform/`, `docker/`, `*.yml` (CI) | `infra`, `devops` |
| `docs/`, `*.md`            | `documentation`               |

**c. From `$ARGUMENTS`:**
- If the user explicitly specifies labels (e.g., `labels: urgent, P0`), use those as-is

Only use labels that actually exist in the repository (`gh label list` output).
If no matching labels exist, omit `--label` entirely. Do NOT create new labels.

### Step 5: Create the PR

```bash
gh pr create --title "[type]: description" --body "..." --assignee @me --label "label1" --label "label2"
```

- `--assignee @me` ensures the PR creator is automatically assigned
- `--label` flags are repeated for each label (omit if no matching labels found)
- Save the PR URL for subsequent steps

### Step 6: Post-creation enhancements (best-effort)

Report the PR URL immediately, then run the following skills. Both are best-effort — failures do not block.

1. **Notion linking**: Run `/link-notion <PR_URL>`
2. **UI screenshots**: Run `/capture-ui <PR_URL>`

### Step 7: Final report

```
=== PR Created ===
PR:     <url>
Assign: @me ✓
Labels: <applied labels / none>
Notion: <linked / not found / skipped>
Screenshots: <N枚添付 / no UI changes / dev server not running>
```

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
[Auto-captured or manual]
```

## Title Format

```
type: concise description (max 72 chars)
```

Types: feat, fix, refactor, docs, test, chore, style, perf

## Checklist Before Creating

- [ ] Changes are committed and pushed
- [ ] Branch is up to date with base
- [ ] Tests pass
- [ ] No merge conflicts
- [ ] PR title follows convention
