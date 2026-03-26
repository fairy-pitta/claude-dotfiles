---
name: capture-ui
description: プロジェクトのVRTスナップショットから差分PNGを検出し、GitHub PRにアップロードする。VRTが未更新なら自動updateする。
---

# Capture UI (VRT-based)

プロジェクトの既存VRT (Visual Regression Testing) を活用してUI差分PNGをPRに貼る。

Context: $ARGUMENTS

`$ARGUMENTS` may contain a PR URL. If not provided, detect from the current branch.

## Process

### Step 1: Determine PR info

If PR URL is provided in `$ARGUMENTS`, use it. Otherwise:
```bash
gh pr view --json url,number -q '"\(.url)\t\(.number)"'
```

If no PR exists for the current branch, report and exit.

### Step 2: VRTの存在確認

プロジェクトにVRTが存在するか確認する。以下を順にチェック:

```bash
# Playwright VRT snapshots
find . -type d -name "*.spec.ts-snapshots" -o -name "*.spec.js-snapshots" | head -5

# Storycap / reg-suit snapshots
ls -d .reg/ __screenshots__/ 2>/dev/null

# Generic snapshot dirs
find . -type d -name "__snapshots__" -path "*/e2e/*" -o -name "__snapshots__" -path "*/visual/*" | head -5
```

また、VRT実行コマンドを特定する:

```bash
# package.json の scripts から VRT 関連コマンドを探す
grep -E '"(vrt|visual|snapshot|screenshot)' package.json frontend/package.json 2>/dev/null

# playwright.config で toHaveScreenshot 設定を探す
grep -rl "toHaveScreenshot\|toMatchSnapshot\|expect.*screenshot" --include="*.ts" --include="*.js" -l | head -5
```

**VRTが見つからない場合** → "VRTが存在しないためスキップします" と報告して終了。

**VRT実行コマンドの特定:**
- `package.json` に `vrt` や `test:visual` 等のスクリプトがあればそれを使う
- なければ Playwright の場合: `npx playwright test --grep visual` や VRT テストファイルを直接指定
- コマンドが特定できない場合は報告して終了

### Step 3: 差分PNGの確認

今回の変更でVRTスナップショットに差分が入っているか確認する:

```bash
BASE=$(git rev-parse --verify origin/dev >/dev/null 2>&1 && echo "dev" || echo "main")
git diff "$BASE"...HEAD --name-only | grep -iE '\.(png|jpg|jpeg)$' | grep -iE 'snapshot|screenshot|visual|vrt|__image_snapshots__'
```

また、未コミットの差分も確認:

```bash
git status --porcelain | grep -iE '\.(png|jpg|jpeg)$' | grep -iE 'snapshot|screenshot|visual|vrt|__image_snapshots__'
```

### Step 4: 差分がない場合 → VRT update

差分PNGが見つからない場合、スナップショットが未更新の可能性がある。VRT updateを実行する:

```bash
# 例: Playwright の場合
npx playwright test --update-snapshots

# 例: package.json にスクリプトがある場合
npm run vrt:update
# or
pnpm run vrt:update
```

**Step 2 で特定したコマンドに `--update-snapshots` フラグを付けて実行する。**

update後、再度差分を確認:

```bash
git status --porcelain | grep -iE '\.(png|jpg|jpeg)$'
```

それでも差分がない場合 → "UI変更なし — スクショをスキップします" と報告して終了。

### Step 5: 差分PNGをPRにアップロード

差分のあるPNGファイルをPRコメントとして投稿する。

```bash
# 差分PNGのパスを収集（git diff + unstaged の両方）
DIFF_PNGS=$(git diff "$BASE"...HEAD --name-only | grep -iE '\.(png)$'; git diff --name-only | grep -iE '\.(png)$')

# Build image args
IMAGE_ARGS=""
for img in $DIFF_PNGS; do
  [ -f "$img" ] || continue
  IMAGE_ARGS+=" --image $img"
done

# Upload and comment
gh attach --issue "$PR_NUMBER" $IMAGE_ARGS --release \
  --body "## UI Screenshots (VRT diff)"
```

If `gh attach` is not installed, install it first:
```bash
gh extension install atani/gh-attach
```

### Step 6: Report

```
=== UI Screenshots (VRT) ===
VRT: detected (<type>)
Snapshots updated: yes / no (already up to date)
Screenshots: <N>枚
PR comment: posted ✓
```

## Error Handling

- VRTが存在しない → report and exit (do not block)
- VRT update コマンドが特定できない → report and exit
- VRT update が失敗 → エラー内容を報告して終了（テスト失敗はブロックしない）
- `gh attach` is not installed → install with `gh extension install atani/gh-attach` and retry
- Upload fails → Read the screenshots locally with the Read tool to view them inline, and report paths to the user
- Never block PR creation — this skill is always best-effort
