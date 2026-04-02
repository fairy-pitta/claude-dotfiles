---
name: status
description: Show current branch, PR status, open worktrees, and uncommitted changes at a glance.
---

# Project Status

現在の作業状態を一覧表示する。

**Announce at start:** "ステータスを確認します"

## Step 1: Gather Information

以下を並列で取得する:

### 1-1. Git Branch & Changes

```bash
# 現在のブランチ
git branch --show-current

# 未コミットの変更
git status --short

# 直近5コミット
git log --oneline -5

# リモートとの差分
git rev-list --left-right --count origin/$(git branch --show-current)...HEAD 2>/dev/null
```

### 1-2. Open Worktrees

```bash
git worktree list
```

マージ済み（リモートブランチが削除済み）のworktreeがあれば警告する。

### 1-3. PR Status

```bash
# 現在のブランチに紐づくPR
gh pr view --json number,title,state,reviewDecision,statusCheckRollup,url 2>/dev/null

# 自分が作成した open PR 一覧
gh pr list --author @me --state open --json number,title,headRefName,reviewDecision,url 2>/dev/null
```

### 1-4. Stash

```bash
git stash list
```

## Step 2: Display

```markdown
=== Project Status ===

## Current Branch
Branch: <branch-name>
Ahead: <N> / Behind: <M> (vs origin)

### Uncommitted Changes
<git status --short output, or "Clean">

### Recent Commits
<last 5 commits>

## PR (this branch)
#<number> <title> — <state> (<reviewDecision>)
Checks: <pass/fail/pending>
URL: <url>

## Open PRs (@me)
| # | Title | Branch | Review |
|---|-------|--------|--------|
| <number> | <title> | <branch> | <decision> |

## Worktrees
| Path | Branch | Status |
|------|--------|--------|
| <path> | <branch> | Active / Mergeable |

## Stash
<stash list, or "None">
```

## Notes

- gh CLI が使えない場合は PR セクションをスキップし、その旨を表示
- worktree のパスは `~` で省略表示
- マージ済みworktreeがある場合: "`/cleanup-worktrees` で削除できます" と案内
