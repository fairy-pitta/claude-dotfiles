---
name: pr-watch
description: PRをCodeRabbitがApproveするまで定期監視。未解決コメントは自律対応、なければfull reviewをリクエスト。ユーザー承認不要の自動運転モード。
---

# PR Watch

PRをCodeRabbitがApproveするまで定期的に監視し、レビューコメントに自律的に対応するスキル。

**ユーザーは寝ている前提。承認待ちせず全て自分で判断して進める。**

**Announce at start:** "pr-watch を開始します。PR #<N> をCodeRabbit Approveまで監視します。"

## 引数

```
/pr-watch [interval] [PR番号]
```

- `interval`: 監視間隔（デフォルト: `1h`）。`30m`, `1h`, `2h` など
- `PR番号`: 省略時は現在のブランチのPR

例:
```
/pr-watch              # 1時間おき、現在ブランチのPR
/pr-watch 30m          # 30分おき
/pr-watch 1h 522       # 1時間おき、PR #522
```

## Step 1: 初期情報の取得

```bash
# PR番号の取得（引数 or 現在ブランチ）
PR_NUMBER=${PR_NUMBER_ARG:-$(gh pr view --json number --jq '.number')}
OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO=$(gh repo view --json name --jq '.name')
```

PR番号・リポジトリ情報を確認して報告。

## Step 2: GraphQLクエリの準備

以下のクエリを `/tmp/pr_query.graphql` に書き出す:

```graphql
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          isResolved
          path
          line
          comments(first: 1) {
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
```

## Step 3: CronCreate でループを設定

引数の `interval` をcron式に変換して `CronCreate` を呼ぶ。

**cronプロンプトには以下のロジックを埋め込む:**

---

### ループ1回分のロジック（プロンプトに含める内容）

**前提: ユーザー承認不要。全て自律的に判断・実行する。**

#### 1. Approve チェック

```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/reviews | \
  jq '[.[] | select(.user.login == "coderabbitai" and .state == "APPROVED")] | length'
```

- **Approve済み（1以上）**: "PR #{PR_NUMBER} はCodeRabbitからApprove済みです。監視を終了します。" と報告し、`CronDelete` でこのジョブを停止。**ここで終了。**

#### 2. 未解決コメント チェック

```bash
gh api graphql \
  -f owner="{OWNER}" -f repo="{REPO}" -F number={PR_NUMBER} \
  -F query=@/tmp/pr_query.graphql | \
  jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
```

#### 3a. 未解決コメントがある場合

`/address-pr-comments` を実行して全件対応する。

**重要ルール:**
- ユーザー承認を待たない。自分で妥当性を判断して進める
- 妥当なコメント → コードを修正 → テスト → コミット → プッシュ
- 妥当でないコメント → PRスレッドに理由を返信（`gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/comments --method POST -F in_reply_to={comment_id} -f body="返信内容"`）
- 全件対応後、`@coderabbitai full review` をPRにコメント

#### 3b. 未解決コメントがない場合

PRコメントの末尾を確認し、直近の `@coderabbitai` を含むコメントが **3回連続** で投稿されていないか確認:

```bash
# 直近5件のコメントを取得し、末尾から連続で @coderabbitai を含むコメントが何件あるか数える
gh api repos/{OWNER}/{REPO}/issues/{PR_NUMBER}/comments --jq \
  '[.[-5:][].body] | reverse | [limit(3; .[] | select(contains("@coderabbitai")))] | length'
```

- **3回未満**: `gh pr comment {PR_NUMBER} --body "@coderabbitai full review"` を投稿
- **3回連続**: スキップ（CodeRabbitが反応しない可能性。次のループを待つ）

---

## Step 4: 期限設定

`CronCreate` のワンショットジョブで、12時間後にループを自動停止するジョブも作成する。

```bash
# 12時間後の時刻を計算
date -v+12H "+%M %H %d %m"
```

## 完了報告

```
=== PR Watch Started ===

PR:       #{PR_NUMBER} ({OWNER}/{REPO})
間隔:     {interval}
自動停止: CodeRabbit Approve時 or 12時間後
ジョブID: {job_id}（手動停止: CronDelete）

監視中... ユーザー操作不要。
```

## Red Flags - Never Do This

- **ユーザーに承認を求めない** — 自律運転モード
- **Approve済みなのにループを続けない** — 即停止
- **`@coderabbitai full review` を4回以上連投しない** — 3回連続で反応なしならスキップ
- **address-pr-comments でPlan Modeに入らない** — 自律モードではPlan Mode不要、直接修正する
- **テストが通らないままコミットしない**
