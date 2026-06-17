# Self Review Skill

複数のレビュースキルをオーケストレーションして、全スキルから指摘がゼロになるまでループするスキル。

## 使用するスキル

| スキル | 適用条件 |
|---|---|
| backend-coderabbit | `backend/` に変更がある場合 |
| frontend-coderabbit | `frontend/` に変更がある場合 |
| design-principles | スタック別（言語非依存: SOLID / デメテルの法則 / クリーンコード）。`backend/`・`frontend/` それぞれに1つ、両方変更時は2つ起動 |

## フロー

```
変更ファイル確認 → スキルセット決定
  ↓
[ラウンド N]
  backend/frontend-coderabbit 並列レビュー
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
