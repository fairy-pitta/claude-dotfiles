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
AUTH_STATE="$HOME/.claude/capture-ui-auth.json"

# Install playwright in temp dir
cd "$WORK_DIR" && npm init -y --silent && npm install playwright --silent

# Write capture script into the same directory
cat > "$WORK_DIR/capture.mjs" << 'SCRIPT'
import { chromium } from 'playwright';
import { existsSync, readFileSync } from 'fs';

const [port, dir, authFile, ...routes] = process.argv.slice(2);
const baseUrl = `http://localhost:${port}`;

// Load saved auth state if available
const contextOptions = { viewport: { width: 1280, height: 720 } };
if (existsSync(authFile)) {
  contextOptions.storageState = authFile;
  console.log('AUTH: loaded saved session from ' + authFile);
}

const browser = await chromium.launch();
const context = await browser.newContext(contextOptions);
const page = await context.newPage();

// Check if authentication is needed
await page.goto(baseUrl + routes[0], { waitUntil: 'networkidle', timeout: 15000 });
const currentUrl = page.url();
const isLoginPage = currentUrl.includes('/login') || currentUrl.includes('/signin') || currentUrl.includes('/auth');

if (isLoginPage) {
  console.log('AUTH: login page detected at ' + currentUrl);

  // Try auto-login with env vars
  const email = process.env.CAPTURE_UI_EMAIL;
  const password = process.env.CAPTURE_UI_PASSWORD;

  if (email && password) {
    console.log('AUTH: attempting auto-login with CAPTURE_UI_EMAIL...');

    // Find and fill email/username field
    const emailField = await page.$('input[type="email"], input[name="email"], input[name="username"], input[id="email"], input[id="username"]');
    if (emailField) await emailField.fill(email);

    // Find and fill password field
    const passField = await page.$('input[type="password"], input[name="password"], input[id="password"]');
    if (passField) await passField.fill(password);

    // Submit
    const submitBtn = await page.$('button[type="submit"], input[type="submit"], button:has-text("ログイン"), button:has-text("Log in"), button:has-text("Sign in")');
    if (submitBtn) await submitBtn.click();

    // Wait for navigation after login
    await page.waitForURL(url => !url.toString().includes('/login') && !url.toString().includes('/signin') && !url.toString().includes('/auth'), { timeout: 10000 }).catch(() => {});
    await page.waitForLoadState('networkidle');

    const afterUrl = page.url();
    if (!afterUrl.includes('/login') && !afterUrl.includes('/signin') && !afterUrl.includes('/auth')) {
      console.log('AUTH: login successful, saving session...');
      await context.storageState({ path: authFile });
    } else {
      console.error('AUTH: login failed — still on login page: ' + afterUrl);
      console.error('AUTH: set CAPTURE_UI_EMAIL and CAPTURE_UI_PASSWORD env vars, or run manual login setup');
      await browser.close();
      process.exit(1);
    }
  } else {
    console.error('AUTH: login required but no credentials provided');
    console.error('AUTH: set CAPTURE_UI_EMAIL and CAPTURE_UI_PASSWORD env vars');
    console.error('AUTH: or run: node capture.mjs <port> <dir> <authFile> --setup');
    await browser.close();
    process.exit(1);
  }
}

// Interactive login setup mode (--setup flag)
if (routes[0] === '--setup') {
  console.log('AUTH: opening browser for manual login...');
  const visibleBrowser = await chromium.launch({ headless: false });
  const visibleContext = await visibleBrowser.newContext({ viewport: { width: 1280, height: 720 } });
  const visiblePage = await visibleContext.newPage();
  await visiblePage.goto(baseUrl, { waitUntil: 'networkidle' });
  console.log('AUTH: please log in manually in the browser window...');
  console.log('AUTH: press Enter in terminal when done.');
  await new Promise(resolve => process.stdin.once('data', resolve));
  await visibleContext.storageState({ path: authFile });
  console.log('AUTH: session saved to ' + authFile);
  await visibleBrowser.close();
  process.exit(0);
}

// Capture screenshots
for (const route of routes) {
  try {
    await page.goto(`${baseUrl}${route}`, { waitUntil: 'networkidle', timeout: 15000 });

    // Check if we got redirected to login (session expired)
    if (page.url().includes('/login') || page.url().includes('/signin')) {
      console.error(`SKIP: ${route} — redirected to login (session expired)`);
      continue;
    }

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
node "$WORK_DIR/capture.mjs" "${PORT}" "${SCREENSHOT_DIR}" "${AUTH_STATE}" "/" "/users"
```

Replace `${PORT}` with detected port. Pass target routes as additional arguments.

#### Authentication

The script handles login-required apps automatically:

1. **Saved session exists** (`~/.claude/capture-ui-auth.json`): Reuses cookies/localStorage from previous login. No re-authentication needed.

2. **No saved session + env vars set**: Auto-fills login form using:
   - `CAPTURE_UI_EMAIL` — email or username
   - `CAPTURE_UI_PASSWORD` — password
   Saves the session after successful login for future runs.

3. **No saved session + no env vars**: Reports auth failure and exits. Instruct the user to either:
   - Set `CAPTURE_UI_EMAIL` and `CAPTURE_UI_PASSWORD` environment variables
   - Or run manual setup: `node capture.mjs <port> <dir> <authFile> --setup` (opens a visible browser for manual login, saves session)

4. **Session expired** (redirected to login during capture): Skips that page and reports it.

**Security note**: `~/.claude/capture-ui-auth.json` contains session cookies. It is gitignored and local-only. Never commit this file.

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
Auth: <saved session / auto-login / manual setup needed>
```

## Error Handling

- If Playwright is not installed → the script installs it automatically in a temp dir
- If dev server is not running → report and exit (do not block)
- If login is required and no credentials → report and instruct user to set env vars or run --setup
- If screenshot capture fails for a specific page → skip that page, continue with others
- If `gh attach` is not installed → install with `gh extension install atani/gh-attach` and retry
- If upload to PR fails → Read the screenshots locally with the Read tool to view them inline, and report paths to the user
- Never block PR creation — this skill is always best-effort
