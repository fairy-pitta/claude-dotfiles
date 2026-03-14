---
name: full-cycle
description: End-to-end implementation cycle that chains plan creation, execution, self-review, fixes, commit, push, and PR creation.
---

# Full Cycle

End-to-end implementation cycle: Plan creation (with Codex validation) -> Plan execution -> Self-review -> Fix -> Commit -> Push -> PR creation.

Context: $ARGUMENTS

## Overview

This skill orchestrates the complete development cycle from planning through to PR creation. It chains existing skills together so you don't have to invoke them manually.

**Announce at start:** "full-cycle を開始します。Plan作成(Codex検証) -> Plan実行 -> Review -> Fix -> Commit -> Push -> PR作成 を自動で回します。"

## Context Management

**Each phase boundary: check context usage. If >= 80%, run `/compact` before continuing.**

---

## Phase 0: Plan Creation & Codex Validation

### 0-1. Gather requirements

- If `$ARGUMENTS` contains a GitHub issue number/URL: fetch it with `gh issue view`
- If `$ARGUMENTS` contains inline instructions: use them as requirements
- If `$ARGUMENTS` is empty: ask the user what to build

### 0-2. Enter plan mode and create the plan

Enter plan mode. Explore the codebase to understand:

- Existing architecture and patterns
- Related files that will need changes
- Test structure and conventions

Write a detailed implementation plan covering:

- **Goal**: What we're building/fixing and why
- **Phases**: Ordered steps with specific file paths and code changes
- **Testing strategy**: What tests to add/modify
- **Verification**: How to confirm each phase works

Save the plan to `.claude/plan.md` in the project root.

### 0-3. Codex review loop

Submit the plan to Codex for review. Loop until Codex approves.

```bash
# Build the prompt with project context
CLAUDE_MD="$(pwd)/CLAUDE.md"
PLAN_FILE=".claude/plan.md"

PROMPT=$(mktemp /tmp/full-cycle-plan-review.XXXXXX)
echo "# Project Rules" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Implementation Plan\n" >> "$PROMPT"
cat "$PLAN_FILE" >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << 'REVIEW_INSTRUCTIONS' >> "$PROMPT"
Review this implementation plan. Check for:
1. Architectural correctness (follows project patterns and conventions)
2. Completeness (no missing steps, edge cases considered)
3. Ordering (dependencies between steps are respected)
4. Testing coverage (adequate tests planned)
5. Risk areas (potential breaking changes, migration issues)

If the plan is good, respond with exactly: LGTM
If there are issues, list them concisely.
REVIEW_INSTRUCTIONS

codex review - < "$PROMPT"
rm -f "$PROMPT"
```

**Parse the output:**

- If Codex responds with `LGTM` (or no actionable issues): proceed to Phase 1
- If Codex has findings: revise the plan to address them, then re-submit
- **Max 3 rounds.** If Codex still has issues after 3 rounds, show the remaining concerns to the user and ask whether to proceed anyway

### 0-4. Plan approved

```
=== Phase 0: Plan Approved ===
Codex review rounds: <N>
Plan: .claude/plan.md
```

#### Context check -> `/compact` if >= 80%

---

## Phase 1: Plan Execution

### 1-1. Read the approved plan

Read `.claude/plan.md` and execute it.

### 1-2. Execute the plan

- Implement all steps from the plan sequentially
- Do NOT stop between steps to ask for confirmation
- Test after each logical milestone
- Commit at logical milestones using `/commit-push` conventions (meaningful messages, split by theme)

### 1-3. Milestone summary

```
=== Phase 1: Plan Execution Complete ===
Commits: <N>
Files changed: <N>
Tests: PASS / FAIL
```

If tests FAIL, fix before proceeding.

### 1-4. Clean up plan file

```bash
rm -f .claude/plan.md
```

#### Context check -> `/compact` if >= 80%

---

## Phase 2: Self-Review

### 2-1. Determine review scope

```bash
git diff --name-only origin/dev...HEAD 2>/dev/null || git diff --name-only origin/main...HEAD
```

If no changed files, skip to Phase 4.

### 2-2. Run review skills

Apply the relevant review skills based on changed files:

| Changed files        | Skills to apply                    |
| -------------------- | ---------------------------------- |
| `backend/` only      | coderabbit-review (backend focus)  |
| `frontend/` only     | coderabbit-review (frontend focus) |
| Both                 | coderabbit-review (full)           |
| Other (OSS, scripts) | coderabbit-review (general)        |

Run `/coderabbit-review` and collect findings.

### 2-3. Report findings

```
=== Phase 2: Review Results ===
Critical: <N>
Major: <N>
Minor: <N>
Trivial: <N>
```

If all zero, skip Phase 3.

#### Context check -> `/compact` if >= 80%

---

## Phase 3: Fix Review Findings

### 3-1. Fix all findings

Priority order: Critical -> Major -> Minor -> Trivial

- Read the file before editing (don't fix blindly)
- Run tests after each batch of fixes

### 3-2. Commit fixes

Use `/commit-push` conventions. Never use vague messages like `fix: レビュー対応`.

### 3-3. Re-review (loop)

Run `/coderabbit-review` again. If new findings emerge, fix and re-review.
**Max 5 rounds.** If findings remain after 5 rounds, report them and proceed.

```
=== Phase 3: Fix Complete ===
Review rounds: <N>
Remaining findings: <N> (if any)
```

#### Context check -> `/compact` if >= 80%

---

## Phase 4: Final Push

### 4-1. Ensure all changes are committed

```bash
git status
```

If uncommitted changes remain, commit them.

### 4-2. Push

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin "$BRANCH"
```

If rejected, pull --rebase and retry.

---

## Phase 5: Create PR

### 5-1. Check if PR already exists

```bash
gh pr list --head "$(git rev-parse --abbrev-ref HEAD)" --state open
```

If a PR already exists, skip PR creation and report the existing PR URL.

### 5-2. Determine base branch

```bash
# Try dev first, fall back to main
git rev-parse --verify origin/dev >/dev/null 2>&1 && echo "dev" || echo "main"
```

### 5-3. Create PR

Use `/create-pr` skill conventions:

- Title: `type: concise description`
- Body: Summary of changes, testing done, related issues
- Link issues with `Closes #N` if applicable

```bash
gh pr create --base <base-branch> --title "..." --body "..." --assignee @me
```

### 5-4. Report

```
=== Full Cycle Complete ===

PR: <URL>
Total commits: <N>
Review rounds: <N>
Files changed: <N>

Summary:
- <bullet point summary of what was done>
```

---

## Critical Constraints

- **Never stop to ask for confirmation mid-cycle** (unless blocked by an error that needs user input)
- **Always run tests before committing**
- **Always use meaningful commit messages** (see CLAUDE.md rules)
- **Context management: compact at 80%**
- **Max 5 review-fix rounds** to prevent infinite loops
- **Never push to main/master directly**
