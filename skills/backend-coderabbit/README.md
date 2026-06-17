# Backend CodeRabbit Review Skill

Django + Clean Architecture/DDD のバックエンドコードに特化したCodeRabbitスタイルのコードレビュースキル。

## 特徴

- **重要度指標:** 🔴 Critical / 🟠 Major / 🟡 Minor / 🔵 Trivial
- **カテゴリラベル:** `_⚠️ Potential issue_` / `_🧹 Nitpick_` / `_🛠️ Refactor suggestion_`
- diff付きのactionableな修正案を提示
- 日本語でのレビュー（【必須修正】【要改善】等のラベル）

## データソース

- 431件のbackendインラインコメント（最近40件のPR）
- 6,328件のユニークコメント（PR #177以前）を統合

## フォーカスエリア（11項目）

1. **Architecture Compliance** - Feature依存, Domain純粋性, DomainRepositoryのDTO依存違反
2. **Type Safety** - Any型禁止, Result型タプルアンパック, `_`でのエラー無視禁止, Enum必須
3. **Security & Authorization** - permission_classes明示, write_only, 認可バイパス防止, オブジェクトレベル認可(IDOR/BOLA), 作成/割り当て時の指定先認可, 関数レベル認可(BFLA), 認可ロジックの層自己完結, PII/機密情報露出防止, マスアサインメント, SQL/コマンドインジェクション, 秘密値のハッシュ保存・非返却, アップロード検証, SSRF, throttle適用範囲, メモリDoS, 依存脆弱性
4. **Error Messages & Constants** - 文字列リテラル禁止, logger/print禁止
5. **Database Performance** - N+1, SELECT*禁止（.only()/.values()使用）, bulk操作
6. **Validation & Error Handling** - 網羅性, エッジケース, 正規化後チェック
7. **Test Quality** - pytest命名順序（動作_条件_期待結果）, fixture活用, CSRFテスト有効化
8. **Unused Code Detection** - 未使用関数・型・定数
9. **Code Organization & DRY** - 重複除去, deprecated API, コメント正確性, 会話文脈・実装履歴コメントの削除
10. **Migration & DB Schema** - リバースマイグレーション, ロールバックリスク
11. **Syntax & Basic Quality** - 構文エラー, 命名規約

## 使用方法

```
/backend-coderabbit
```
