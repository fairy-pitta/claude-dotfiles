---
name: capture-ui
description: Detect UI changes, take screenshots from the local dev server, and upload them to the GitHub PR.
---

# Capture UI Screenshots

Detect UI file changes on the current branch, take screenshots from the local dev server using Playwright, and upload them to the GitHub PR as a comment.

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
for port in 5173 3000 8080 4173; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null)
  [ "$code" = "200" ] && echo "$port" && break
done
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

### Step 5: Capture screenshots with Playwright

Create a temp working directory with Playwright installed, write a capture script, and execute it.

**IMPORTANT**: Playwright must be resolved from the same directory as the script. Always write the script into the temp directory where `playwright` is installed.

```bash
WORK_DIR=$(mktemp -d)
SCREENSHOT_DIR=$(mktemp -d)

# Install playwright in temp dir
cd "$WORK_DIR" && npm init -y --silent && npm install playwright --silent

# Write capture script into the same directory
cat > "$WORK_DIR/capture.mjs" << 'SCRIPT'
import { chromium } from 'playwright';
const [port, dir, ...routes] = process.argv.slice(2);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
for (const route of routes) {
  try {
    await page.goto(`http://localhost:${port}${route}`, { waitUntil: 'networkidle', timeout: 15000 });
    const name = route.replace(/\//g, '_').replace(/^_/, '') || 'top';
    await page.screenshot({ path: `${dir}/${name}.png`, fullPage: true });
    console.log(`OK: ${route} -> ${name}.png`);
  } catch (e) {
    console.error(`SKIP: ${route} — ${e.message}`);
  }
}
await browser.close();
SCRIPT

# Run capture
node "$WORK_DIR/capture.mjs" "${PORT}" "${SCREENSHOT_DIR}" "/" "/users"
```

Replace `${PORT}` with detected port. Pass target routes as additional arguments.

### Step 6: Upload screenshots to PR

Use `gh attach` (gh extension) to upload images and post a PR comment with embedded screenshots:

```bash
# Build image args
IMAGE_ARGS=""
for img in "$SCREENSHOT_DIR"/*.png; do
  [ -f "$img" ] || continue
  IMAGE_ARGS+=" --image $img"
done

# Upload and comment (--release mode uses GitHub Releases, no browser needed)
gh attach --issue "$PR_NUMBER" $IMAGE_ARGS --release \
  --body "## UI Screenshots (auto-captured)"
```

If `gh attach` is not installed, install it first:
```bash
gh extension install atani/gh-attach
```

Flags:
- `--release`: uploads via GitHub Releases (no browser automation needed)
- `--width 800`: default image width (adjustable)
- `--image`: repeatable, one per screenshot file

### Step 7: Cleanup and report

```bash
rm -rf "$WORK_DIR" "$SCREENSHOT_DIR"
```

```
=== UI Screenshots ===
Pages captured: <list of routes>
Screenshots: <N>枚
PR comment: posted ✓
```

## Error Handling

- If Playwright is not installed → the script installs it automatically in a temp dir
- If dev server is not running → report and exit (do not block)
- If screenshot capture fails for a specific page → skip that page, continue with others
- If `gh attach` is not installed → install with `gh extension install atani/gh-attach` and retry
- If upload to PR fails → Read the screenshots locally with the Read tool to view them inline, and report paths to the user
- Never block PR creation — this skill is always best-effort
