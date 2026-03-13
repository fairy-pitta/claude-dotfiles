---
name: reviewer
description: PR inline code review - runs backend-coderabbit or frontend-coderabbit (5 parallel sub-agents, auto-detected) then posts each comment directly on the GitHub PR diff as individual inline comments
---

# PR Inline Reviewer

Run a `backend-coderabbit` / `frontend-coderabbit` style code review (**5 parallel sub-agents per side**, auto-detected from changed files), then **post each finding directly on the PR as an individual inline comment** on the corresponding code line using `gh api`.

**Core principle:** Leverage parallel sub-agents for thorough analysis, then deliver results as inline PR comments — not as one big summary comment.

**Announce at start:** "reviewer スキルで5並列レビューしてインラインコメントを投稿します"

## Workflow Overview

```
Step 1: Identify PR and get metadata (PR number, commit SHA, owner/repo)
Step 2: Perform code review using 5 parallel sub-agents per side
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

## Step 2: Perform Code Review (5 Parallel Sub-Agents)

**変更ファイルのパスを見てレビュー観点を自動選択する。**

```bash
git diff --name-only origin/<base_branch>...HEAD
```

| 変更ファイルのパス | 使用するサブエージェント |
|---|---|
| `backend/` のみ | **backend-coderabbit** 5並列 |
| `frontend/` のみ | **frontend-coderabbit** 5並列 |
| 両方混在 | **両方** 最大10並列 |
| その他（`.github/`, `CLAUDE.md` 等） | 一般的なコード品質チェック |

### サブエージェント起動

各サブエージェントへの共通プロンプト:

```
あなたはコードレビューのサブエージェントです。

1. チェックリストを読む: `<checklist_path>`
2. コード例示を読む: `<skill_dir>/references/code-examples.md`
3. プロジェクトの CLAUDE.md を読む
4. `git diff --name-only origin/<base_branch>...HEAD -- '<path_filter>'` で変更ファイルを取得
5. 各変更ファイルを読んでレビューを実施（全項目必須）
6. 結果をテーブル + 詳細フォーマットで返す

コードの修正は行わず、検出と報告のみ行うこと。
```

**Backend 5エージェント:**

| description | checklist |
|------------|-----------|
| `backend-review: architecture` | `backend-coderabbit/checklists/architecture.md` |
| `backend-review: type-safety` | `backend-coderabbit/checklists/type-safety.md` |
| `backend-review: db-performance` | `backend-coderabbit/checklists/db-performance.md` |
| `backend-review: test-quality` | `backend-coderabbit/checklists/test-quality.md` |
| `backend-review: security-errors` | `backend-coderabbit/checklists/security-errors.md` |

**Frontend 5エージェント:**

| description | checklist |
|------------|-----------|
| `frontend-review: fsd-architecture` | `frontend-coderabbit/checklists/fsd-architecture.md` |
| `frontend-review: type-state` | `frontend-coderabbit/checklists/type-state.md` |
| `frontend-review: error-vue` | `frontend-coderabbit/checklists/error-vue.md` |
| `frontend-review: tanstack-security` | `frontend-coderabbit/checklists/tanstack-security.md` |
| `frontend-review: test-quality` | `frontend-coderabbit/checklists/test-quality.md` |

### 結果のマージ

全サブエージェントの結果を集約・重複排除し、各指摘について記録:

- ファイルパス
- 行番号
- 重要度
- 簡潔な説明

## Step 3: Present Findings for User Approval

**CRITICAL: Do NOT post comments until user approves.**

Present findings as a table in Japanese:

```markdown
## 指摘予定リスト

| # | 重要度 | カテゴリ | ファイル | 行 | 内容 |
|---|--------|---------|----------|-----|------|
| 1 | Medium | architecture | `path/to/file.py` | 42 | 簡潔な説明 |
| 2 | Low | type-safety | `path/to/other.ts` | 100 | 簡潔な説明 |
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

## Red Flags - Never Do This

- **Never post comments without user approval** — always present the list first and wait
- **Never post all comments as a single summary** — each finding must be an individual inline comment on the specific code line
- **Never guess positions** — always calculate from the actual diff output
- **Never skip the diff position calculation** — using file line numbers directly will fail
- **Never use the `line` or `subject_type` API parameters** — use `position` only
- **Never add fluff or excuses to comments** — keep them direct and concise
- **Never post on lines outside the diff** — use general PR comments for those
- **Never skip the parallel sub-agent review** — this skill's value is combining thorough domain-specific review with precise PR delivery
- **Never apply backend observations to frontend files or vice versa** — always match the review checklist to the file's path
- **Never run sub-agents sequentially** — always launch all in parallel
