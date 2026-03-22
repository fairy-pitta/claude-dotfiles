---
name: pr-watch
description: PRをCodeRabbitがApproveするまで定期監視。未解決コメントはサブエージェントで自律対応。ユーザー承認不要の自動運転モード。（デフォルト: CC Agent、--codex で codex CLI）
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

**コンテキスト管理:** 各ステップの完了後にコンテキスト使用率を確認し、**80%以上なら `/compact` を実行**してから次のステップへ進む。

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

CodeRabbitの**最新レビュー**（APPROVED or CHANGES_REQUESTED）の状態を確認する。過去にAPPROVEDがあっても、その後CHANGES_REQUESTEDが来ていれば未Approveとみなす。

```bash
gh api repos/{OWNER}/{REPO}/pulls/{PR_NUMBER}/reviews | \
  jq '[.[] | select(.user.login == "coderabbitai[bot]" and (.state == "APPROVED" or .state == "CHANGES_REQUESTED"))] | last | .state'
```

- **`"APPROVED"`**: "PR #{PR_NUMBER} はCodeRabbitからApprove済みです。監視を終了します。" と報告し、`CronDelete` でこのジョブを停止。**ここで終了。**

#### 3. 未解決コメント チェック

```bash
gh api graphql \
  -f owner="{OWNER}" -f repo="{REPO}" -F number={PR_NUMBER} \
  -F query=@/tmp/pr_query.graphql | \
  jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
```

#### 4a. 未解決コメントがある場合 → サブエージェントに全委託

**CCはコードを読まず、修正もしない。** 全てをサブエージェントに委託し、結果サマリーだけ受け取る。

**エンジン選択:** `$ARGUMENTS` に `--codex` が含まれる場合は codex CLI、それ以外は Agent が直接実装する。

Agent tool で起動:

```
description: "pr-watch: fix unresolved comments"
prompt: |
  あなたはPRコメント対応のサブエージェントです。
  ユーザー承認不要の自律運転モード。全て自分で判断して進めてください。

  ## PR情報
  - PR: #{PR_NUMBER}
  - Repo: {OWNER}/{REPO}

  ## タスク

  ### 1. 未解決コメント取得
  以下のGraphQLクエリで未解決スレッドを取得:

  gh api graphql \
    -f owner="{OWNER}" -f repo="{REPO}" -F number={PR_NUMBER} \
    -F query=@/tmp/pr_query.graphql | \
    jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'

  ### 2. 各コメントの妥当性判断
  各コメントについて:
  1. 対象コードを Read tool で読む（必須）
  2. CLAUDE.md を読む
  3. CODING_STANDARDS.md があれば読む
  4. 判定: 妥当 / スコープ外 / 妥当でない

  ### 3. 対応実行

  **妥当なコメント → 修正:**
  1. 修正計画を `.claude/pr-fix-plan.md` に書き出す
  2. plan に従い、Edit tool / Write tool でコードを直接修正する
  3. テスト実行（pytest / type-check / lint / test:unit）
  4. テスト失敗 → 修正して再テスト（最大3回）
  5. `/commit-push` でコミット＆プッシュ
  6. 各 comment_id に「Fixed in {commit_hash}」を返信

  **スコープ外コメント:**
  - ファイル内完結 → 上記と同様に修正
  - 大規模 → GitHub Issue 作成 → PRスレッドにIssueリンクを返信

  **妥当でないコメント → PRスレッドに理由を返信:**
  gh api repos/{OWNER}/{REPO}/pulls/comments/{comment_id}/replies \
    --method POST --field body="{理由}"

  ### 4. レビュー観点追加
  修正した指摘について、チェックリストに観点を追記:
  - backend/ → ~/claude-dotfiles/skills/backend-coderabbit/checklists/ 配下
  - frontend/ → ~/claude-dotfiles/skills/frontend-coderabbit/checklists/ 配下
  追記後: cd ~/claude-dotfiles && git add skills/ && git commit -m "feat: PR#{PR_NUMBER}の指摘からレビュースキルに観点を追加" && git push

  ### 5. クリーンアップ
  rm -f .claude/pr-fix-plan.md

  ### 6. 結果レポート
  以下の形式で返す:

  ## Fix Result
  - 修正: N件
  - Issue作成: N件
  - 返信: N件（妥当でない旨）
  - 観点追加: N件
  - テスト: PASS / FAIL
```

**--codex 指定時のサブエージェント:** 上記の「### 3. 対応実行」の修正部分を以下に差し替える:

```
  **妥当なコメント → codex cli で修正:**
  1. 修正計画を `.claude/pr-fix-plan.md` に書き出す
  2. codex cli で実装:

  ```bash
  CLAUDE_MD="$(pwd)/CLAUDE.md"
  PROMPT=$(mktemp /tmp/pr-watch-fix.XXXXXX)
  echo "# Project Rules (MUST follow)" > "$PROMPT"
  [ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
  echo -e "\n---\n# Fix Plan\n" >> "$PROMPT"
  cat .claude/pr-fix-plan.md >> "$PROMPT"
  echo -e "\n---\nImplement the fix plan. Follow project conventions. Run tests." >> "$PROMPT"
  codex - < "$PROMPT"
  rm -f "$PROMPT"
  ```
```

サブエージェントの結果サマリーを確認後、`@coderabbitai full review` をPRにコメント:

```bash
gh pr comment {PR_NUMBER} --body "@coderabbitai full review"
```

**full review連投カウンタをリセットする。**

その後、**Step 5: 遅延Approveチェック** へ進む。

#### 4b. 未解決コメントがない場合 → full review リクエスト

PRコメントの末尾から、**自分が投稿した `@coderabbitai` を含むコメントが連続何件あるか**数える:

```bash
gh api repos/{OWNER}/{REPO}/issues/{PR_NUMBER}/comments --jq \
  '[.[].body] | reverse | [limit(10; .[] | select(contains("@coderabbitai")))] | length'
```

- **5回未満**: `gh pr comment {PR_NUMBER} --body "@coderabbitai full review"` を投稿 → **Step 5: 遅延Approveチェック** へ進む
- **5回連続で無反応（Approveもコメントもなし）**: → **PRを再作成する**（Step 6 へ）

---

## Step 4: 期限設定

`CronCreate` のワンショットジョブで、12時間後にループを自動停止するジョブも作成する。

```bash
date -v+12H "+%M %H %d %m"
```

## Step 5: 遅延Approveチェック（full review投稿後）

`@coderabbitai full review` を投稿した直後はApproveされない。CodeRabbitの処理時間を考慮し、**20分待ってからApproveと未解決コメントを再チェックする。**

```
1. sleep 1200  （20分待機）
2. Approveチェック（Step 3-2 と同じクエリ）
   - Approve済み → 監視終了（CronDelete）
   - 未Approve → 未解決コメントチェック（Step 3-3 と同じクエリ）
     - 未解決コメントあり → Step 3-4a と同じサブエージェント対応 → full review投稿 → 再度20分待機して再チェック（最大2回まで）
     - 未解決コメントなし → 次のcronまで待機
```

**注意:**
- 1回のcron実行内で遅延チェックは**最大2回**まで（無限ループ防止）
- 2回チェックしてもApproveされない場合は次のcron実行まで待機

## Step 6: PR再作成（5回無反応時）

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
- **CCが直接コードを読まない・修正しない** — サブエージェントに委託（デフォルト: Agent直接実装、--codex: codex cli）
- **Approve済みなのにループを続けない** — 即停止
- **ステータステーブルを省略しない** — 毎ループ必ず出力する
- **テストが通らないままコミットしない**
- **6回以上 full review を連投しない** — 5回無反応ならPR再作成
- **コンテキスト80%超えのまま `/compact` せずに次ステップへ進まない**
