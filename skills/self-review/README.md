# Self Review Skill

複数のレビュースキルをオーケストレーションして、全スキルから指摘がゼロになるまでループするスキル。

## 使用するスキル

| スキル | 適用条件 |
|---|---|
| sora-review | 常に適用 |
| backend-coderabbit | `backend/` に変更がある場合 |
| frontend-coderabbit | `frontend/` に変更がある場合 |
| frontend-architecture | `frontend/` に変更がある場合 |

## フロー

```
変更ファイル確認 → スキルセット決定
  ↓
[ラウンド N]
  sora-review → backend/frontend-coderabbit → frontend-architecture
  ↓
全指摘ゼロ？ → Yes → 完了
           ↓ No
  修正 → テスト全実行 → コミット → ラウンド N+1
```

## コンテキスト管理

**コンテキスト80%で `/compact` を自動実行。** トークンを大量消費するため必須。

## 使用方法

```
/self-review
```
