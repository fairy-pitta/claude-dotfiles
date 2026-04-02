---
name: cleanup-worktrees
description: List and remove git worktrees whose branches have been merged or deleted on remote.
---

# Cleanup Worktrees

マージ済み・削除済みブランチのworktreeを一括削除する。

**Announce at start:** "worktreeのクリーンアップを確認します"

## Step 1: List Worktrees

```bash
git worktree list --porcelain
```

メインworktree（bare含む）は除外する。

## Step 2: Check Each Worktree

各worktreeについて:

```bash
# ブランチ名を取得
BRANCH=$(git -C <worktree-path> branch --show-current)

# リモートブランチが存在するか
git ls-remote --heads origin "$BRANCH" 2>/dev/null

# PRがマージ済みか
gh pr list --head "$BRANCH" --state merged --json number,title,mergedAt 2>/dev/null
```

分類:
- **Merged**: PRがマージ済み → 削除候補
- **Remote deleted**: リモートブランチが存在しない → 削除候補
- **Active**: リモートにブランチが存在し、未マージ → 残す
- **Dirty**: 未コミットの変更がある → 警告して残す

```bash
# 未コミット変更チェック
git -C <worktree-path> status --porcelain
```

## Step 3: Confirm

削除候補を表示してユーザーに確認する:

```markdown
=== Worktree Cleanup ===

### 削除候補
| Path | Branch | Reason |
|------|--------|--------|
| ~/path/to/wt1 | feature/foo | PR #123 merged |
| ~/path/to/wt2 | fix/bar | Remote branch deleted |

### 残すもの
| Path | Branch | Reason |
|------|--------|--------|
| ~/path/to/wt3 | feature/baz | Active (open PR #456) |

削除してよいですか？ (Y/n)
```

**ユーザーの確認なしに削除しない。**

`$ARGUMENTS` に `--dry-run` がある場合はリスト表示のみで終了。

## Step 4: Remove

ユーザーが承認した場合:

```bash
# worktree 削除
git worktree remove <worktree-path>

# ローカルブランチも削除（マージ済みの場合）
git branch -d <branch-name> 2>/dev/null
```

削除に失敗した場合（ロックされている等）:

```bash
git worktree remove --force <worktree-path>
```

それでも失敗 → エラーを報告してスキップ。

## Step 5: Report

```
=== Cleanup Complete ===
Removed: <N> worktrees
- <path> (<branch>) — <reason>

Skipped: <N>
- <path> (<branch>) — <reason>

Remaining worktrees: <N>
```

## Red Flags

- **未コミット変更があるworktreeを削除しない**
- **メインworktreeを削除しない**
- **Active（未マージ）のworktreeを勝手に削除しない**
- **ユーザー確認なしに削除しない**（`--force` 引数がある場合を除く）
