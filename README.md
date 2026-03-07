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

| コマンド               | 説明                                                        |
| ---------------------- | ----------------------------------------------------------- |
| `/backend-coderabbit`  | Backend専用レビュー（Django/DDD/Clean Architecture）        |
| `/frontend-coderabbit` | Frontend専用レビュー（Vue 3/TypeScript/FSD/TanStack Query） |
| `/sora-review`         | カジュアルスタイルのコードレビュー（lits0ra風）             |
| `/reviewer`            | レビュー実行後、PRにインラインコメントとして投稿            |
| `/self-review`         | 全レビュースキルを順番に実行し、指摘ゼロまでループ          |
| `/review-loop`         | backend/frontend-coderabbit を繰り返し実行し全指摘を解消    |
| `/codex-review`        | Codex CLIによる非インタラクティブレビュー                   |

### PR・GitHub連携系

| コマンド               | 説明                           |
| ---------------------- | ------------------------------ |
| `/create-pr`           | PRを作成                       |
| `/address-pr-comments` | PRの未解決コメントを取得し対応 |
| `/read-pr-comments`    | PRの未解決コメントを読み取り   |
| `/resolve-comments`    | PRレビュースレッドを解決       |
| `/fix-review`          | レビュー指摘を修正（1回）      |
| `/fix-and-learn`       | PRコメントを修正しつつ学習     |

### Git操作系

| コマンド           | 説明                                   |
| ------------------ | -------------------------------------- |
| `/commit-push`     | コミット＆プッシュ（squash/amend/new） |
| `/push`            | 現在のブランチをリモートにプッシュ     |
| `/create-worktree` | Git worktreeを作成                     |

### 開発サイクル系

| コマンド                 | 説明                                                            |
| ------------------------ | --------------------------------------------------------------- |
| `/full-cycle`            | Plan作成→Codex検証→実装→レビュー→修正→コミット→PR作成を一気通貫 |
| `/frontend-architecture` | CODING_STANDARDS.md の全項目を並列チェック                      |
| `/process-scans`         | スキャンPDFの分類・整理ワークフロー                             |

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
