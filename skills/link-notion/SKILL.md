---
name: link-notion
description: Search Notion for a task matching the current branch, then bidirectionally link Notion task and GitHub PR.
---

# Link Notion Task

Search Notion for a task related to the current branch and create bidirectional links between the Notion task and the GitHub PR.

Context: $ARGUMENTS

`$ARGUMENTS` may contain a PR URL. If not provided, detect from the current branch.

## Process

### Step 1: Determine PR info

If PR URL is provided in `$ARGUMENTS`, use it. Otherwise:
```bash
gh pr view --json url,title,number -q '"\(.url)\t\(.title)\t\(.number)"'
```

If no PR exists for the current branch, report and exit.

### Step 2: Extract search keywords

Extract keywords from multiple sources (try in order):

1. **Branch name** — strip prefix and convert separators to spaces:
   - `feat/add-user-settings` → `add user settings`
   - `fix/TASK-123-login-bug` → `TASK-123 login bug`
2. **PR title** — strip type prefix:
   - `feat: ユーザー設定画面を追加` → `ユーザー設定画面を追加`
3. **Commit messages** (last 5) — extract common keywords

### Step 3: Search Notion

Use `mcp__claude_ai_Notion__notion-search` with extracted keywords:

```json
{
  "query": "<keywords>",
  "query_type": "internal"
}
```

**Search strategy:**
- First try branch-derived keywords
- If no results, try PR title keywords
- If still no results, try shorter/broader keywords (e.g., just the core noun)
- Max 3 search attempts

### Step 4: Select best match

If multiple results:
- Prefer pages whose title closely matches the branch name or PR title
- Prefer task/issue-type pages over general docs
- If ambiguous, pick the top result

If no results after all attempts → report "Notionタスクが見つかりませんでした" and exit.

### Step 5: Add PR link to Notion

Use `mcp__claude_ai_Notion__notion-create-comment` to add a comment:

```json
{
  "page_id": "<notion-page-id>",
  "rich_text": [
    {
      "text": {
        "content": "PR: <pr-url>",
        "link": { "url": "<pr-url>" }
      }
    }
  ]
}
```

### Step 6: Add Notion link to PR

Append the Notion page URL to the PR description:

```bash
CURRENT_BODY=$(gh pr view <pr-number> --json body -q .body)
gh pr edit <pr-number> --body "$(cat <<EOF
$CURRENT_BODY

## Notion Task
[<task-title>](<notion-url>)
EOF
)"
```

### Step 7: Report

```
=== Notion Linked ===
Notion: <task-title> (<notion-url>)
PR:     <pr-url>
Direction: bidirectional ✓
```

## Error Handling

- If Notion MCP is unavailable → report "Notion MCPが利用できません" and exit
- If search returns no results → report and exit (do not block)
- If comment creation fails → report error but still attempt to add Notion link to PR
- Never create or modify Notion page content — only add comments
