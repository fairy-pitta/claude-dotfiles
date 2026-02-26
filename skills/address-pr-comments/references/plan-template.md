# Plan Mode テンプレート

Plan Mode で提示する修正計画のフォーマット。

```
## 修正計画

**作業ブランチ:** `<branch-name>`（worktree: `.git-worktrees/<branch-name>`）

| # | 優先度 | ファイル | 行 | 内容 | 修正方針 |
|---|--------|---------|-----|------|---------|
| 1 | 🔴 | `path/to/file.ts` | 42 | 指摘概要 | 具体的な修正方法 |
| 2 | 🟠 | `backend/app/...` | 88 | 指摘概要 | 具体的な修正方法 |

## 検証・コミット
- ruff check / type-check / pytest 等
- `/commit-push` スキルでコミット＆プッシュ

## Post-Fix（自動実行）
コミット＆プッシュ後、Stop hook が以下を自動実行:
- PRスレッドに修正コミット通知を返信
- 妥当でないコメントに返信
- レビュースキルに観点を追加（claude-dotfiles）
```

## 優先度の定義

1. 🔴 Critical / セキュリティ・バグ
2. 🟠 Major / アーキテクチャ・型安全性
3. 🟡 Minor / リファクタ
4. 🔵 Trivial / スタイル・Nitpick
