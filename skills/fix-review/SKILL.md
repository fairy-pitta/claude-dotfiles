---
name: fix-review
description: Address unresolved review comments for a branch by working in a dedicated git worktree.
---

# Fix Review Points

Address unresolved review comments on branch: $ARGUMENTS

## Setup

1. **Create/access worktree**
   - Use `/create-worktree $ARGUMENTS`
   ```bash
   cd .git-worktrees/$(echo "$ARGUMENTS" | tr '/' '-')
   pwd  # Verify location
   ```

## Process

2. **Analyze unresolved comments**
   ```bash
   gh pr view --json reviewThreads --jq '.reviewThreads[] | select(.isResolved == false) | {path: .path, line: .line, body: .comments[0].body}'
   ```

3. **Plan fixes**
   - Use Explore sub-agent to understand each issue
   - Use Plan sub-agent to create fix strategy

4. **Execute fixes**
   - Address each comment sequentially
   - Use general-purpose sub-agent for implementation

5. **テストを全て実行して通過を確認（必須）**
   - unit / integration テストが存在する場合は実行
   - e2e テストが存在する場合は実行
   - VRT（Visual Regression Test）が存在する場合は実行
   - いずれかが失敗している場合はコミットせず、先に修正する

6. **Commit and push**
   - Use `/commit-push`
   - コミットメッセージは**何を修正したかが具体的にわかる**内容にする（必須）

   **禁止表現（絶対に使わない）:**

   | ❌ 禁止 | 理由 |
   |---|---|
   | `fix: PRレビュー指摘を反映` | 何を直したか不明 |
   | `fix: レビュー対応` | 同上 |
   | `fix: コメント対応` | 同上 |
   | `fix: 諸々修正` | 複数変更を丸めている |

   **良い例:**
   ```
   fix: UserRepositoryがPresentation DTO(AuthUserPayload)を返す依存方向を是正
   fix: v-forのkeyをindex→posting_idに変更してDOM再利用の不整合を防止
   refactor: テスト命名をtest_<動作>_<条件>_<期待結果>の順序に統一
   ```

   **複数テーマにまたがる場合はコミットを分割する。**
   1つのメッセージで表現しきれない変更は、テーマごとに分けて複数コミットにすること。

7. **Resolve threads**
   ```bash
   # Resolve via GitHub UI or API
   gh api graphql -f query='...'
   ```

7. **Update PR**
   - Update PR description with fix summary
   - Request re-review
   ```bash
   gh pr comment --body "Review feedback addressed. Please re-review."
   ```

## Critical Constraints

- ALL work within the worktree only
- Verify with `pwd` before changes
- Do not modify outside the worktree

## Output

- List of fixed issues
- Updated PR description
- Re-review requested
