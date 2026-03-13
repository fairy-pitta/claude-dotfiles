---
name: capture-ui
description: Detect UI changes, take screenshots from the local dev server, and upload them to the GitHub PR.
---

# Capture UI Screenshots

Detect UI file changes on the current branch, take screenshots from the local dev server using browser automation, and upload them to the GitHub PR as a comment.

Context: $ARGUMENTS

`$ARGUMENTS` may contain a PR URL. If not provided, detect from the current branch.

## Process

### Step 1: Determine PR info

If PR URL is provided in `$ARGUMENTS`, use it. Otherwise:
```bash
gh pr view --json url,number -q '"\(.url)\t\(.number)"'
```

If no PR exists for the current branch, report and exit.

### Step 2: Detect UI changes

```bash
BASE=$(git rev-parse --verify origin/dev >/dev/null 2>&1 && echo "dev" || echo "main")
git diff "$BASE"...HEAD --name-only | grep -E '\.(vue|tsx|jsx|css|scss|sass|html|svelte)$'
```

If no UI-related file changes → report "UI変更なし — スクショをスキップします" and exit.

### Step 3: Detect dev server

Check common local dev server ports:
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:5173 2>/dev/null
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 2>/dev/null
curl -s -o /dev/null -w "%{http_code}" http://localhost:4173 2>/dev/null
```

Use the first port that returns HTTP 200.

If no dev server is running → report "dev serverが起動していないためスクショをスキップします" and exit.

### Step 4: Infer target pages

From the changed file paths, infer which pages/routes to screenshot:

| Changed file pattern | Likely route |
|---------------------|-------------|
| `pages/users/*`, `views/users/*` | `/users` |
| `components/Login.*` | `/login` |
| `layouts/Default.*` | `/` (top page) |

- If route inference is unclear, screenshot the top page (`/`)
- Capture at most 5 pages to keep the process fast

### Step 5: Capture screenshots

Use `mcp__claude-in-chrome__tabs_create_mcp` to open a new tab, then for each target page:

1. Navigate: `mcp__claude-in-chrome__navigate` to `http://localhost:<port>/<route>`
2. Wait for page load: `mcp__claude-in-chrome__computer` with `action: "wait"`, `duration: 2`
3. Screenshot: `mcp__claude-in-chrome__computer` with `action: "screenshot"`
4. Note the `imageId` from the screenshot result

### Step 6: Upload screenshots to PR

1. Open the PR page: `mcp__claude-in-chrome__navigate` to the PR URL
2. Scroll to the comment box at the bottom of the PR
3. Click on the comment textarea
4. For each screenshot:
   - Use `mcp__claude-in-chrome__upload_image` with the `imageId` to attach the image
   - Wait briefly for upload to complete
5. Type a comment header: "## UI Screenshots (auto-captured)"
6. Submit the comment

### Step 7: Report

```
=== UI Screenshots ===
Pages captured: <list of routes>
Screenshots: <N>枚
PR comment: posted ✓
```

## Error Handling

- If browser tools are unavailable → report and exit
- If dev server is not running → report and exit (do not block)
- If screenshot capture fails for a specific page → skip that page, continue with others
- If upload to PR fails → save screenshot info locally and report paths
- Never block PR creation — this skill is always best-effort
