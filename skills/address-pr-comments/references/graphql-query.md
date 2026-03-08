# GraphQL: 未解決レビュースレッド全件取得

## クエリ実行

```bash
PR_NUMBER=$(gh pr view --json number --jq '.number')
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')

gh api graphql --paginate \
  -f owner="$OWNER" \
  -f repo="$REPO" \
  -F number="$PR_NUMBER" \
  -f query='
    query($owner: String!, $repo: String!, $number: Int!, $endCursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $endCursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              isResolved
              path
              line
              comments(first: 20) {
                nodes {
                  databaseId
                  author { login }
                  body
                }
              }
            }
          }
        }
      }
    }
  ' | jq -s '
    [.[].data.repository.pullRequest.reviewThreads.nodes[]]
    | map(select(.isResolved == false))
    | map({
        id: .id,
        path: .path,
        line: .line,
        comment_count: (.comments.nodes | length),
        first_comment: {
          author: .comments.nodes[0].author.login,
          body: .comments.nodes[0].body,
          comment_id: (.comments.nodes[0].databaseId | tostring)
        },
        last_comment: {
          author: .comments.nodes[-1].author.login,
          body: .comments.nodes[-1].body,
          comment_id: (.comments.nodes[-1].databaseId | tostring)
        },
        all_comments: [.comments.nodes[] | {author: .author.login, body: .body, comment_id: (.databaseId | tostring)}]
      })
  '
```

## 共通操作

### スレッドを resolve する

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: {threadId: "<thread_id>"}) {
      thread { isResolved }
    }
  }
'
```

### スレッドに返信する

```bash
gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  --method POST \
  --field body="<返信内容>"
```

### GitHub Issue を作成する

```bash
gh issue create \
  --title "<指摘内容の要約>" \
  --body "$(cat <<'EOF'
PR #<PR_NUMBER> のレビューで指摘された内容。

## 指摘内容
<コメント本文>

## 対象ファイル
`<path>:<line>`
EOF
)"
```

Issue作成後、スレッドに `Created <Issue URL>` と返信して resolve する。
