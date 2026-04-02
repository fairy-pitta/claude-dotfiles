# Claude Code Dotfiles

Claude Code の設定・スキル・スクリプトをポータブルに管理するリポジトリ。

## セットアップ

```bash
git clone https://github.com/fairy-pitta/claude-dotfiles.git ~/.claude/claude-dotfiles
cd ~/.claude/claude-dotfiles
./setup.sh
```

## 構成

```
.
├── CLAUDE.md                  # グローバルルール（全セッション共通）
├── settings.json              # ステータスライン・プラグイン設定
├── settings.local.json        # パーミッション設定
├── mcp-servers.json           # MCPサーバー定義
├── statusline-command.sh      # ステータスライン表示スクリプト
├── setup.sh                   # セットアップスクリプト
├── scripts/                   # フックスクリプト
│   ├── auto-format.sh         # 編集後の自動フォーマット（Prettier/Black）
│   ├── deny-check.sh          # 危険コマンドのブロック
│   └── statusline-command.sh  # ステータスライン
└── skills/                    # カスタムスキル（スラッシュコマンド）
    └── references/            # スキル間共有リファレンス
```

## スキル一覧

### コードレビュー系

| コマンド        | 説明                                                     |
| --------------- | -------------------------------------------------------- |
| `/backend-review`  | Backend専用レビュー（Django/DDD/Clean Architecture）5並列 |
| `/frontend-review` | Frontend専用レビュー（Vue 3/TypeScript/FSD/TanStack Query）5並列 |
| `/reviewer`        | レビュー実行後、PRにインラインコメントとして投稿         |
| `/self-review`     | 全工程エージェント委託。REVIEW→TRIAGE→FIX→COMMITを指摘ゼロまでループ |
| `/review-loop`     | backend/frontend-review を繰り返し実行し全指摘を解消     |
| `/codex-review`    | 非インタラクティブレビュー（CC Agent / codex CLI）       |

### PR・GitHub連携系

| コマンド             | 説明                                        |
| -------------------- | ------------------------------------------- |
| `/create-pr`         | PR作成＋Notion連携＋VRTスナップショット     |
| `/iterate-pr`        | PRの未解決コメントを取得→判断→修正フルループ |
| `/resolve-comments`  | 対応済みPRレビュースレッドを解決            |
| `/pr-watch`          | PR自動監視・CodeRabbit承認まで修正ループ    |
| `/link-notion`       | Notionタスクとの双方向リンク                |
| `/capture-ui`        | VRTスナップショット差分をPRにアップロード   |

### Git操作系

| コマンド              | 説明                                         |
| --------------------- | -------------------------------------------- |
| `/commit-push`        | コミット＆プッシュ（squash/amend/new）       |
| `/push`               | 現在のブランチをリモートにプッシュ           |
| `/create-worktree`    | Git worktreeを作成                           |
| `/cleanup-worktrees`  | マージ済みworktreeを検出し一括削除           |

### 開発サイクル系

| コマンド          | 説明                                                  |
| ----------------- | ----------------------------------------------------- |
| `/codex-plan`     | Plan作成→レビューループ→ユーザー承認→実装             |
| `/resolve-issues` | GitHub Issuesから並列にworktreeで調査→実装→PR作成     |
| `/test`           | テスト実行＋失敗時の自動修正（pytest / vitest対応）   |
| `/status`         | ブランチ・PR・worktree・stashの一覧表示              |
| `/process-scans`  | スキャンPDFの分類・整理ワークフロー                   |

### 共有リファレンス (`references/`)

| ファイル            | 内容                                                 |
| ------------------- | ---------------------------------------------------- |
| `review-format.md`  | 重要度・カテゴリ・コメント構造・サマリーテンプレート |
| `review-process.md` | レビュープロセス（ファイル分類・手順）               |
| `code-examples.md`  | backend/frontend共通のコード例                       |

## CLAUDE.md グローバルルール

全セッションに適用されるルール:

- **言語**: 業務プロジェクト→日本語 / OSSプロジェクト→英語
- **実行スタイル**: 途中で止まらず最後まで実行
- **コミットメッセージ**: `type: 具体的な説明`（抽象的な表現禁止）
- **テスト命名**: `test_<動作>_<条件>_<期待結果>`
- **Git**: main/masterへの直接コミット禁止

## MCPサーバー

- **Playwright** — ブラウザ自動操作
- **Serena** — セマンティックコード検索

## パーミッション設定

**許可:** ファイル編集、Git操作、npm/pnpmコマンド、基本操作

**拒否:** `rm -rf /*`、`chmod 777`、`git config --global`、`git push --force`

## 前提条件

- Node.js 18+
- [uv](https://github.com/astral-sh/uv)（Serena MCP用）
- Claude Code (`npm install -g @anthropic-ai/claude-code`)
