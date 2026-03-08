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
```

## Step 3: CronCreate でループを設定

引数の `interval` をcron式に変換して `CronCreate` を呼ぶ。

**cronプロンプトには以下のロジックを埋め込む:**

---

### ループ1回分のロジック（プロンプトに含める内容）

**前提: ユーザー承認不要。全て自律的に判断・実行する。**

#### 1. PR情報の取得とステータステーブルの表示

毎回のループ開始時に、以下の情報を取得してテーブルで表示する:

```bash
# PR情報を取得
gh pr view {PR_NUMBER} --json title,headRefName,body,state,reviews,url
```

**必ず以下のテーブルを出力してからチェックに進む:**

```
=== PR Watch Status ===

| 項目 | 内容 |
|------|------|
| PR | #{PR_NUMBER} <PR URL> |
| タイトル | <PRタイトル> |
| ブランチ | <head branch> |
| 概要 | <PR bodyの先頭100文字> |
| ステータス | <OPEN/CLOSED/MERGED> |
| CodeRabbit | <Approved / Changes Requested / Pending> |
| full review連投数 | <N>回（無反応連続） |
| 次回チェック | <現在時刻 + interval>（例: 23:30） |

監視中... 次回チェックまで待機します。
```

#### 2. Approve チェック

```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/reviews | \
  jq '[.[] | select(.user.login == "coderabbitai" and .state == "APPROVED")] | length'
```

- **Approve済み（1以上）**: "PR #{PR_NUMBER} はCodeRabbitからApprove済みです。監視を終了します。" と報告し、`CronDelete` でこのジョブを停止。**ここで終了。**

#### 3. 未解決コメント チェック

```bash
gh api graphql \
  -f owner="{OWNER}" -f repo="{REPO}" -F number={PR_NUMBER} \
  -F query=@/tmp/pr_query.graphql | \
  jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
```

#### 4a. 未解決コメントがある場合

`/address-pr-comments` を実行して全件対応する。

**重要ルール:**
- ユーザー承認を待たない。自分で妥当性を判断して進める
- 妥当なコメント → コードを修正 → テスト → コミット → プッシュ
- 妥当でないコメント → PRスレッドに理由を返信
- 全件対応後、`@coderabbitai full review` をPRにコメント
- **full review連投カウンタをリセットする**（コメント対応後の再リクエストは新規扱い）

#### 4b. 未解決コメントがない場合 → full review リクエスト

PRコメントの末尾から、**自分が投稿した `@coderabbitai` を含むコメントが連続何件あるか**数える:

```bash
gh api repos/{OWNER}/{REPO}/issues/{PR_NUMBER}/comments --jq \
  '[.[].body] | reverse | [limit(10; .[] | select(contains("@coderabbitai")))] | length'
```

- **5回未満**: `gh pr comment {PR_NUMBER} --body "@coderabbitai full review"` を投稿
- **5回連続で無反応（Approveもコメントもなし）**: → **PRを再作成する**（Step 5 へ）

---

## Step 4: 期限設定

`CronCreate` のワンショットジョブで、12時間後にループを自動停止するジョブも作成する。

```bash
date -v+12H "+%M %H %d %m"
```

## Step 5: PR再作成（5回無反応時）

CodeRabbitが5回連続で `@coderabbitai full review` に反応しない場合、PRを閉じて同じ内容で再作成する。

```bash
# 現在のPR情報を保存
TITLE=$(gh pr view {PR_NUMBER} --json title --jq '.title')
BODY=$(gh pr view {PR_NUMBER} --json body --jq '.body')
HEAD=$(gh pr view {PR_NUMBER} --json headRefName --jq '.headRefName')
BASE=$(gh pr view {PR_NUMBER} --json baseRefName --jq '.baseRefName')
LABELS=$(gh pr view {PR_NUMBER} --json labels --jq '[.labels[].name] | join(",")')

# 現在のPRを閉じる
gh pr close {PR_NUMBER} --comment "CodeRabbitが反応しないため、PRを再作成します。"

# 同じ内容で新しいPRを作成
NEW_PR=$(gh pr create --title "$TITLE" --body "$BODY" --head "$HEAD" --base "$BASE" ${LABELS:+--label "$LABELS"})
NEW_PR_NUMBER=$(echo "$NEW_PR" | grep -oE '[0-9]+$')

# 報告
echo "PR #{PR_NUMBER} を閉じ、PR #${NEW_PR_NUMBER} を再作成しました。"
```

**再作成後:**
- CronDelete で現在の監視ジョブを停止
- 新しいPR番号で `/pr-watch {interval} ${NEW_PR_NUMBER}` を再起動
- full review連投カウンタはリセットされる

## 完了報告

```
=== PR Watch Started ===

| 項目 | 内容 |
|------|------|
| PR | #{PR_NUMBER} ({OWNER}/{REPO}) |
| タイトル | <PRタイトル> |
| ブランチ | <head branch> |
| 間隔 | {interval} |
| 自動停止 | CodeRabbit Approve時 or 12時間後 |
| ジョブID | {job_id}（手動停止: CronDelete） |

監視中... ユーザー操作不要。
```

## Red Flags - Never Do This

- **ユーザーに承認を求めない** — 自律運転モード
- **Approve済みなのにループを続けない** — 即停止
- **ステータステーブルを省略しない** — 毎ループ必ず出力する
- **address-pr-comments でPlan Modeに入らない** — 自律モードではPlan Mode不要、直接修正する
- **テストが通らないままコミットしない**
- **6回以上 full review を連投しない** — 5回無反応ならPR再作成
