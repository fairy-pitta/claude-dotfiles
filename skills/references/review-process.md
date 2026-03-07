# Review Process Reference

Shared review process for all CodeRabbit-style review skills.

## 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD
```

## 2. Classify Files

| 変更ファイルのパス | 使用するスキル/観点              |
| ------------------ | -------------------------------- |
| `backend/` のみ    | backend-coderabbit               |
| `frontend/` のみ   | frontend-coderabbit              |
| 両方混在           | 両スキルを各ファイルに対して適用 |
| その他             | 一般的なコード品質チェック       |

## 3. Review Each File

1. ファイルを Read tool で読む
2. Core Checklist の全項目をチェック（省略禁止）
3. 変更内容に応じて Extended Checklist をチェック
4. CLAUDE.md のプロジェクトルールと照合
5. 意図的・自明な指摘はフィルタアウト

各指摘について記録:

- ファイルパス
- 行番号
- 重要度
- 簡潔な説明

## 4. Generate Summary

`references/review-format.md` の Review Summary Template に従う。
