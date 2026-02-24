---
name: reviewer
description: PR inline code review - runs backend-coderabbit or frontend-coderabbit (auto-detected) then posts each comment directly on the GitHub PR diff as individual inline comments
---

# PR Inline Reviewer

Run a `backend-coderabbit` / `frontend-coderabbit` style code review (auto-detected from changed files), then **post each finding directly on the PR as an individual inline comment** on the corresponding code line using `gh api`.

**Core principle:** Leverage backend-coderabbit / frontend-coderabbit skills for thorough analysis, then deliver results as inline PR comments — not as one big summary comment.

**Announce at start:** "reviewer スキルでレビューしてインラインコメントを投稿します"

## Workflow Overview

```
Step 1: Identify PR and get metadata (PR number, commit SHA, owner/repo)
Step 2: Perform code review using coderabbit-review methodology
Step 3: Present findings list to user for approval (MUST WAIT)
Step 4: After user approval, get numbered diff and calculate positions
Step 5: Post each finding as an inline comment via gh api
```

## Step 1: Identify PR and Get Metadata

```bash
# Find the PR for the current branch
BRANCH=$(git branch --show-current)
gh pr list --head "$BRANCH" --state open --json number,title,url

# Get the latest commit SHA
COMMIT_SHA=$(gh pr view <PR_NUMBER> --json headRefOid --jq '.headRefOid')

# Get owner/repo
gh repo view --json nameWithOwner --jq '.nameWithOwner'
# Returns: "owner/repo"

# Get changed files
git diff --name-only origin/<base_branch>...HEAD
```

If no PR exists, inform the user and stop.

## Step 2: Perform Code Review

**変更ファイルのパスを見てレビュー観点を自動選択する。**

```bash
git diff --name-only origin/<base_branch>...HEAD
```

| 変更ファイルのパス | 使用する観点 |
|---|---|
| `backend/` のみ | **backend-coderabbit** の11観点を全適用 |
| `frontend/` のみ | **frontend-coderabbit** の11観点を全適用 |
| 両方混在 | **両スキル**の観点を各ファイルに対して適用 |
| その他（`.github/`, `CLAUDE.md` 等） | 一般的なコード品質チェック |

### backend-coderabbit の11観点（`backend/` ファイルに適用）

1. **Architecture Compliance** — Feature間依存, Domain純粋性, DomainRepositoryのDTO依存違反, Transaction配置
2. **Type Safety** — Any型禁止, Result型タプルアンパック, `_`でエラー無視はNG, Enum必須
3. **Security & Authorization** — permission_classes明示, write_only, 認可バイパス経路
4. **Error Messages & Constants** — 文字列リテラル禁止, logger/print禁止
5. **Database Performance** — N+1, SELECT*禁止（.only()/.values()）, bulk操作
6. **Validation & Error Handling** — 網羅性, エッジケース, 正規化後チェック, 年範囲検証
7. **Test Quality** — pytest命名順序（動作_条件_期待結果）, fixture活用, CSRF有効化, 正常系カバレッジ
8. **Unused Code Detection** — 未使用関数・型・定数・import
9. **Code Organization & DRY** — 重複除去, deprecated API, コメント正確性, 型アノテーション一貫性
10. **Migration & DB Schema** — リバースマイグレーション, ロールバックリスク
11. **Syntax & Basic Quality** — 構文エラー, マージコンフリクトマーカー, 命名規約

### frontend-coderabbit の11観点（`frontend/` ファイルに適用）

1. **FSD Architecture Compliance** — index.ts経由import必須（最多指摘）, features間import禁止, ComposablesとRepository IFの関係
2. **Type Safety** — any/enum/console禁止, branded型（Amount）, `<script setup lang="ts">`必須
3. **TanStack Vue Query** — QueryKey Factoryパターン, Pinia非推奨, 楽観更新禁止, invalidateQueries
4. **State Management** — composable singletonのreadonly保護, computed活用
5. **Error Handling** — エラーカタログ定数（直書き禁止）, 4層パイプライン
6. **Vue.js Patterns** — v-for key安定性, 非同期レースコンディション, Floating Promise, UIガード一致
7. **Test Quality** — MSW, FormData axios adapter, 型安全モック, テストケース網羅性
8. **Security** — XSS対策（v-html）, 脆弱ライブラリ（xlsx等）
9. **Unused Code Detection** — 未使用composable・型・import
10. **Code Organization & DRY** — コンポーネント分割, @pages/エイリアス, ルーター命名一貫性
11. **Syntax & Basic Quality** — TS構文エラー, マージコンフリクトマーカー

### 共通手順

1. Diffを取得: `git diff origin/<base_branch>...HEAD`
2. 各変更ファイルを読んでコンテキストを把握
3. 上記の観点を各ファイルのパスに応じて適用
4. CLAUDE.mdのプロジェクトルールと照合
5. 意図的・自明な指摘はフィルタアウト

For each finding, record:
- The target file path
- The target line number in the file
- Brief description of the issue

## Step 3: Present Findings for User Approval

**CRITICAL: Do NOT post comments until user approves.**

Present findings as a table in Japanese:

```markdown
## 指摘予定リスト

| # | 重要度 | ファイル | 行 | 内容 |
|---|--------|----------|-----|------|
| 1 | Medium | `path/to/file.ts` | 42 | 簡潔な説明 |
| 2 | Low | `path/to/other.vue` | 100 | 簡潔な説明 |
...

どれを投稿するか、修正・削除したい項目はありますか？
```

Wait for user to:
- Approve all
- Remove specific items
- Modify specific items
- Discuss specific items

Only proceed to Step 4 after explicit approval.

## Step 4: Calculate Diff Positions

The GitHub API requires a `position` parameter (not a file line number) to place inline comments. The position is calculated from the diff output.

**How to calculate:**

```bash
# Get the cumulative diff with global line numbers
gh pr diff <PR_NUMBER> | awk '{printf "%4d | %s\n", NR, $0}'
```

For each file in the diff, find the **first `@@` hunk line**. The position of any target line is:

```
position = target_diff_line_number - first_@@_line_number_for_that_file
```

**Example:**
```
 250 | diff --git a/src/foo.ts b/src/foo.ts
 251 | index abc..def 100644
 252 | --- a/src/foo.ts
 253 | +++ b/src/foo.ts
 254 | @@ -9,16 +9,65 @@          <-- First @@ for this file
 255 |  import { something }        <-- position = 255 - 254 = 1
 256 | +const newCode = true        <-- position = 256 - 254 = 2
 ...
 314 | +  return result             <-- position = 314 - 254 = 60
```

**IMPORTANT:**
- Only lines that appear in the diff can receive inline comments
- Both added (+), removed (-), and context lines can be commented on
- Position counting continues across multiple `@@` hunks within the same file (positions do NOT reset at each hunk)
- The first `@@` line of the file is the reference point (position 0); all subsequent lines count from there

## Step 5: Post Inline Comments

Use `gh api` to post each comment individually on the exact code line:

```bash
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments \
  --method POST --input - <<'JSONEOF'
{
  "body": "<comment body in markdown>",
  "commit_id": "<COMMIT_SHA>",
  "path": "<relative/file/path>",
  "position": <calculated_position>
}
JSONEOF
```

**Parameters:**
- `body`: The review comment (see Comment Format below)
- `commit_id`: The HEAD commit SHA of the PR
- `path`: Relative file path from repo root (e.g., `frontend/src/components/Foo.vue`)
- `position`: The calculated position in the diff (see Step 4)

**For files NOT in the diff** (e.g., pointing out that a constant in another file became unused):
Post as a general PR comment instead:

```bash
gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
  --method POST -f body="<comment body>"
```

## Comment Format

**Keep comments concise and direct. No fluff.**

Format:
```
[カテゴリ - 重要度] タイトル

簡潔な説明（1-2文）

```diff
- old code
+ new code
```
```

**Style rules:**
- NO `##` headers — just `[カテゴリ - 重要度]`
- NO trailing particles like 「ね」「かな」「かも」
- NO follow-up excuses like 「このままでもOK」「今の規模なら問題ない」
- NO unnecessary context like 「CLAUDE.md的には」
- Let the diff speak for itself — minimal explanation needed
- Write in Japanese

**Good example:**
```
[エラーハンドリング - Medium] エラーメッセージがハードコード

`'登録に失敗しました'` が定数化されてない

```diff
-  submitError.value = e instanceof Error ? e.message : '登録に失敗しました'
+  submitError.value = e instanceof Error ? e.message : VALIDATION_MESSAGES.REGISTRATION_FAILED
```
```

**Bad example:**
```
## [エラーハンドリング - Medium] エラーメッセージがハードコードされてるね

ここの `'登録に失敗しました'` がベタ書きになってるね。CLAUDE.md的には `messageConstants.ts` に定数化した方がいいかも。今の規模なら問題ないけど、将来的には統一しておくと安心かな。
```

## Practical Tips

### JSON Escaping in Comment Body

When the comment body contains special characters (quotes, backticks, newlines), use `--input -` with a heredoc and proper JSON:

```bash
gh api repos/{owner}/{repo}/pulls/{PR_NUMBER}/comments \
  --method POST --input - <<'JSONEOF'
{
  "body": "line1\nline2\n\n```diff\n- old\n+ new\n```",
  "commit_id": "abc123",
  "path": "src/foo.ts",
  "position": 42
}
JSONEOF
```

**Tips for JSON body construction:**
- Newlines in the body must be `\n`
- Quotes must be escaped as `\"`
- Backticks do not need escaping in JSON strings
- Use `\n\n` for paragraph breaks

### Verifying Position Accuracy

Before posting, verify a position is correct by checking what line it maps to:
1. Find the file's first `@@` in the numbered diff output
2. Add the position to get the target diff line number
3. Confirm that line contains the code you want to comment on

### Handling Errors

If `gh api` returns a 422 error with "position is not valid":
- The calculated position doesn't fall within a diff hunk
- The line you're targeting is not part of the changed diff
- Solution: Recalculate the position or post as a general PR comment instead

If `gh api` returns a 422 error with `"subject_type" is not a permitted key`:
- Do NOT use `line`, `side`, or `subject_type` parameters
- Use only `body`, `commit_id`, `path`, and `position`

## Red Flags - Never Do This

- **Never post comments without user approval** — always present the list first and wait
- **Never post all comments as a single summary** — each finding must be an individual inline comment on the specific code line
- **Never guess positions** — always calculate from the actual diff output
- **Never skip the diff position calculation** — using file line numbers directly will fail
- **Never use the `line` or `subject_type` API parameters** — use `position` only
- **Never add fluff or excuses to comments** — keep them direct and concise
- **Never post on lines outside the diff** — use general PR comments for those
- **Never skip the backend-coderabbit / frontend-coderabbit review** — this skill's value is combining thorough domain-specific review with precise PR delivery
- **Never apply backend observations to frontend files or vice versa** — always match the review checklist to the file's path

---

**Remember:** This skill combines the thoroughness of backend-coderabbit / frontend-coderabbit (auto-selected by file path) with the precision of inline PR comments. Each comment appears directly on the code line in the PR diff view, making it easy for developers to see exactly what needs attention and where.
