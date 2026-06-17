# Frontend CodeRabbit Review Skill

Vue 3 + TypeScript + FSD (Feature-Sliced Design) + TanStack Vue Query のフロントエンドコードに特化したCodeRabbitスタイルのコードレビュースキル。

## 特徴

- **重要度指標:** 🔴 Critical / 🟠 Major / 🟡 Minor / 🔵 Trivial
- **カテゴリラベル:** `_⚠️ Potential issue_` / `_🧹 Nitpick_` / `_🛠️ Refactor suggestion_`
- diff付きのactionableな修正案を提示
- 日本語でのレビュー（【必須修正】【要改善】等のラベル）

## データソース

- 394件のfrontendインラインコメント（最近40件のPR）
- 既存スキルのフロントエンド観点を統合

## フォーカスエリア（11項目）

1. **FSD Architecture Compliance** - index.ts経由import必須, features間import禁止, ComposablesとRepository IFの関係
2. **Type Safety** - any/enum/console禁止, branded型（Amount）, 型ガード
3. **TanStack Vue Query** - QueryKey Factoryパターン, Pinia非推奨, 楽観更新禁止
4. **State Management** - composable singletonのreadonly保護, computed活用
5. **Error Handling** - エラーカタログ定数, 4層パイプライン
6. **Vue.js Patterns** - v-for key安定性, 非同期レースコンディション, Floating Promise
7. **Test Quality** - MSW, FormData axios adapter, 型安全モック
8. **Security** - XSS対策, 脆弱ライブラリ（xlsx等）, 秘密情報をAPI型/スキーマに含めない
9. **Unused Code Detection** - 未使用composable・型・import
10. **Code Organization & DRY** - コンポーネント分割, @pages/エイリアス, 会話文脈・実装履歴コメントの削除
11. **Syntax & Basic Quality** - TS構文エラー, `<script setup lang="ts">`必須

## 使用方法

```
/frontend-coderabbit
```
