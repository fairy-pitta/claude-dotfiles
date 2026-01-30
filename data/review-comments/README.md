# Review Comments Data

This directory contains comprehensive review comment data collected from the forval-crossgear repository.

## Data Collection

**Date:** 2026-01-30
**Repository:** WAOTech-Team/forval-crossgear
**PRs Analyzed:** 322 (all open + closed)

## Files

### coderabbit_all_comments.txt.gz (6.0 MB)
- **Total comments:** 745,367 lines
- **PRs with comments:** 177
- **Uncompressed size:** 26 MB

**Top PRs by comment count:**
- PR#299: 301 comments
- PR#294: 250 comments
- PR#199: 200 comments
- PR#298: 193 comments
- PR#295: 180 comments

**Analysis (from 6,328 unique comments):**
- 🔵 Trivial: 2,401 (38%)
- 🟠 Major: 1,220 (19%)
- 🔴 Critical: 677 (11%)
- 🟡 Minor: 378 (6%)

**Categories:**
- 🧹 Nitpick: 2,401 (38%)
- ⚠️ Potential issue: 1,830 (29%)
- 🛠️ Refactor: 445 (7%)

### lits0ra_all_comments.txt.gz (11 KB)
- **Total comments:** 603 lines
- **PRs with comments:** 50
- **Uncompressed size:** 39 KB

**Top PRs by comment count:**
- PR#294: 100 comments
- PR#20: 33 comments
- PR#144: 30 comments
- PR#99: 21 comments
- PR#83: 21 comments

**Analysis (from 429 unique comments):**
- Questions (でしょうか): 65
- Repeated issues (ditto/これも): 31
- Requests (お願いします): 21
- Concerns (気がします): 13
- nits: 3

**Top Keywords:**
- Type/Any: 29 mentions
- Constants: 9 mentions
- Transaction: 5 mentions
- N+1/Performance: 3 mentions
- Security: 3 mentions

### review_analysis_full.txt (1.3 KB)
Detailed statistical analysis of both reviewers' comment patterns.

## Usage

To extract the data:
```bash
gunzip -k coderabbit_all_comments.txt.gz
gunzip -k lits0ra_all_comments.txt.gz
```

## Data Format

Each line follows the format:
```
PR#<number>: <full comment body in markdown>
```

Comments preserve:
- Full markdown formatting
- Code blocks and diffs
- Emoji indicators
- Japanese text
- Links and references

## Purpose

This data was used to create and improve:
- `coderabbit-review` skill - Formal, systematic code review
- `sora-review` skill - Casual, conversational code review

Both skills are available in the `skills/` directory.

## Collection Method

Data collected using GitHub CLI (`gh api`) with:
- Pull request inline comments (`/pulls/{pr}/comments`)
- Pull request review comments (`/pulls/{pr}/reviews`)
- Issue-level PR comments (`/issues/{pr}/comments`)

All comments filtered by reviewer username:
- `coderabbitai[bot]` or similar CodeRabbit bot accounts
- `lits0ra` user account

Total collection time: ~30 minutes for 322 PRs

## Statistics

| Metric | CodeRabbit | lits0ra |
|--------|-----------|---------|
| Total comments | 745,367 lines | 603 lines |
| Unique comments | 6,328 | 429 |
| PRs reviewed | 177 | 50 |
| Comment rate | 1.95% of PRs | 15.5% of PRs |
| Avg per PR | 35.8 comments | 8.6 comments |

## Notes

- CodeRabbit comments include auto-generated analysis chains and walkthrough summaries
- lits0ra comments are more concise and question-focused
- Data includes both Japanese and English comments
- Severity indicators and categories are preserved in markdown format
