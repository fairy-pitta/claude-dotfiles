# pr-context.md テンプレート

`.claude/pr-context.md` に書き出すフォーマット。

```markdown
# PR Comment Resolution Context

## メタ情報
- PR: #<number> (<url>)
- Owner/Repo: <owner>/<repo>
- ブランチ: <branch-name>
- Worktree: <worktree-path>

## 妥当なコメント（修正対象）

### 修正 1: <ファイルパス>:<行番号>
- **投稿者:** @<author>
- **comment_id:** <comment_id>
- **コメント概要:** <概要>
- **修正方針:** <具体的な修正方法>
- **優先度:** 🔴/🟠/🟡/🔵
- **レビュー観点候補:** <この指摘から得られるレビュー観点。セルフレビューで検出できなかった理由と、次回検出するためのチェックポイント>
- **対象スキル:** backend-coderabbit / frontend-coderabbit

### 修正 2: ...

## 妥当でないコメント（返信対象）

### 返信 1: <ファイルパス>:<行番号>
- **投稿者:** @<author>
- **comment_id:** <comment_id>
- **コメント概要:** <概要>
- **妥当でない理由:** <理由>
- **返信文案:** <PRスレッドに投稿する返信内容>

### 返信 2: ...

## Post-Fix ワークフロー（コード修正・コミット完了後に実行）

以下の作業を Task tool サブエージェントで実行すること。
`.claude/pr-context.md` を Read tool で読み、必要な情報を取得してから作業する。

### Task A: PRスレッドに修正コミットハッシュを返信
修正した各コメントの comment_id に対して以下を実行:
  COMMIT_HASH=$(git rev-parse --short HEAD)
  gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
    --method POST \
    --field body="Fixed in ${COMMIT_HASH}"
コミットを分割した場合は、各コメントに対応する正しいハッシュを使うこと。

### Task B: 妥当でないコメントへの返信
各コメントの comment_id に対して、「返信文案」の内容でスレッドに返信:
  gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
    --method POST \
    --field body="<返信文案の内容>"

### Task C: レビュースキルへの観点追加（最重要・スキップ禁止）
修正した内容はセルフレビューを潜り抜けてきた欠点。次回以降 self-review で検出されるよう、
レビュースキルに観点を追記する。

対象スキルファイル:
- backend/ 配下の修正 → ~/claude-dotfiles/skills/backend-coderabbit/SKILL.md
- frontend/ 配下の修正 → ~/claude-dotfiles/skills/frontend-coderabbit/SKILL.md

追記フォーマット（PR番号などの由来注釈は付けない。観点単体で意味が通る恒久ルールとして書く）:
  - **<観点名>** — <何をチェックするかの説明>。<なぜ問題になるか>。<どうすれば良いか>。

各修正コメントの「レビュー観点候補」フィールドを参考にすること。
既存セクションに収まらない場合は、最も近いセクションの末尾に追記する。
追記後:
  cd ~/claude-dotfiles && git add skills/ && git commit -m "feat: PR#<number>の指摘からレビュースキルに観点を追加" && git push
```
