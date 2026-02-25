---
name: frontend-coderabbit
description: Frontend専用 CodeRabbit-style code review - Vue 3 + TypeScript + FSD (Feature-Sliced Design) + TanStack Queryの観点で体系的・網羅的にレビュー。Djangoバックエンドは対象外。
---

# Frontend CodeRabbit Review

Vue 3 + TypeScript + FSD (Feature-Sliced Design)のフロントエンドコードをCodeRabbitスタイルで体系的にレビューする。

**Announce at start:** "I'm using the frontend-coderabbit skill to perform a comprehensive frontend code review."

**Data source:** 394 frontend inline comments from 33 PRs (recent 40 PRs analyzed)

**コード例示:** `references/code-examples.md` を参照

## Language

**日本語で回答すること。**タイトルに【必須修正】【要改善】【任意】等のラベルを使用する。

## Review Personality

- Formal & systematic
- 重要度を必ず明記し、actionableな修正案（diffつき）を必ず提示
- ファイルパスと行番号を参照
- `<details>` collapsibleで修正案を展開

## Comment Structure

```
_<category>_ | _<severity>_

**<title>**

<explanation>

<details>
<summary>🔧 修正案</summary>

```diff
<before/after diff>
```
</details>
```

## Severity Indicators

- **🔴 Critical** - マージ前必須修正（セキュリティ、データ損失、クラッシュ）
- **🟠 Major** - 修正推奨（機能影響、FSDアーキテクチャ違反、型安全性）
- **🟡 Minor** - 改善推奨（リファクタ、軽微な最適化）
- **🔵 Trivial** - コードスタイル（未使用import、フォーマット）

## Category Labels

- `_⚠️ Potential issue_` - バグ・ロジック問題・FSD違反
- `_🧹 Nitpick_` - コード品質・スタイル
- `_🛠️ Refactor suggestion_` - アーキテクチャ改善

---

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^frontend/"
```

### 2. Core チェック（全PRで必ず実施）

変更ファイルを読んだ後、**Core Checklist** の全項目をチェックする。
見落としゼロを優先。ファイル数が多い場合でもCore観点は省略しない。

### 3. Extended チェック（変更内容に応じて実施）

変更内容がテスト・クエリ管理・セキュリティ等に関係する場合、
**Extended Checklist** の対応セクションをチェックする。

### 4. Generate Summary

```markdown
## Review Summary

**Actionable comments posted: <N>**

### Severity Distribution
- 🔴 Critical: <N>
- 🟠 Major: <N>
- 🟡 Minor: <N>
- 🔵 Trivial: <N>

### Key Findings

**FSD Architecture:** ...
**Type Safety:** ...
**TanStack Query:** ...
**State Management:** ...
**Vue.js Patterns:** ...
**Test Quality:** ...

### Recommendations
1. **マージ前必須修正:** [Critical/Major]
2. **修正推奨:** [Minor]
3. **任意改善:** [Trivial]
```

---

## Core Checklist（全PRで必ずチェック）`[最頻出・最重要]`

### FSD Architecture `[最多頻出: FSD 21回, import 15回]`

- [ ] **index.ts（公開API）経由のimport必須** — 外部スライスの内部モジュールへの直接importは絶対NG。`@entities/company/api/companyApi` ではなく `@entities/company` 経由（→ `references/code-examples.md`）
- [ ] **features間の直接import禁止** — features間の直接import（型importも含む）は禁止。共有したい型・ロジックは`entities/`または`shared/`に昇格
- [ ] **依存方向** — `app → pages → features → entities → shared`（上位→下位のみ）。pages層はfeatures内部（`model/`, `lib/`等）を直接参照禁止
- [ ] **FSDエイリアス必須** — 相対パスではなく`@app/`, `@pages/`, `@features/`, `@entities/`, `@shared/`のエイリアスを使用

### Type Safety `[型: 40回 - 最多頻出]`

- [ ] **`any`型禁止** — `any`は禁止。`unknown`/`never`/ジェネリクス/型ガードで代替
- [ ] **`enum`禁止** — TypeScriptの`enum`は禁止。`const + as const + typeof`で代替（→ `references/code-examples.md`）
- [ ] **`console.*`禁止** — `console.log/warn/error`等は禁止。エラーは4層パイプライン経由
- [ ] **`<script setup lang="ts">`必須** — `lang="ts"`の省略禁止

### TanStack Vue Query

- [ ] **QueryKey Factoryパターン** — QueryKeyは必ずFactoryパターンで定義。マスターデータは`['master', ...]` prefix必須（→ `references/code-examples.md`）
- [ ] **Pinia非推奨** — サーバー状態をPiniaとTanStack Queryの両方で管理しない。サーバー状態はTanStack Queryに集約

### State Management

- [ ] **composable singletonのreadonly保護** — module-levelのrefをそのまま公開しない。`readonly()`でラップして外部から直接書き込まれないようにする（→ `references/code-examples.md`）

### Error Handling `[エラー: 25回]`

- [ ] **エラーメッセージ直書き禁止** — 文字列リテラルで直書きせず、カタログ定数経由（→ `references/code-examples.md`）

### Vue.js Patterns

- [ ] **`v-for`の`:key`安定性** — `:key`にarray indexを使用していないか。`id`等の安定した識別子を使用（→ `references/code-examples.md`）
- [ ] **Floating Promises** — `async`関数を`await`も`void`もなしに呼び出していないか。意図的なfire-and-forgetは`void`を明示

### Unused Code Detection

- [ ] **未使用の関数・composable・コンポーネント・import** — 呼び出されていない定義が残っていないか

### Syntax & Basic Quality

- [ ] **TypeScript構文エラー・型不一致**
- [ ] **マージコンフリクトマーカー** — `<<<<<<<`が残っていないか
- [ ] **SFCの構造** — `<template>` → `<script setup lang="ts">` → `<style scoped>`の順

---

## Extended Checklist（変更内容に応じてチェック）

### FSD Architecture（詳細）

- **entities間の`@x`パターン** — entities間は`import type`のみ許可。ランタイムimportは禁止
- **3+スライスから使用される機能の昇格** — 3スライス以上から参照されるコードは上位層に昇格必須
- **Composables→Repository IFを介さず実装に直結はNG** — ComposablesがhttpClient等に直結すると依存方向違反（→ `references/code-examples.md`）

### Type Safety（詳細）

- **型アサーション`as`の使用** — 強制キャストが型安全でないケースに注意。型ガードで代替推奨
- **金額にFloat演算禁止** — 金額に浮動小数点演算を直接使わない。`Amount`型（branded integer）経由

### TanStack Vue Query（詳細）

- **QueryKeyに`undefined`を渡さない** — キャッシュ汚染の原因。デフォルト値を設定
- **楽観的更新禁止（仕訳Mutation）** — 仕訳関連のMutationで楽観的更新は禁止。冪等キー必須
- **Mutation後のinvalidateQueries** — Mutationの`onSuccess`で関連QueryKeyを`invalidateQueries`しているか

### State Management（詳細）

- **`computed`の使用** — テンプレート内の複雑な条件式は`computed`に切り出す

### Error Handling（詳細）

- **非対称なdisabled状態** — 同一フローで複数ボタンがある場合、ローディングガードが全ボタンに対称に付いているか（→ `references/code-examples.md`）
- **try-catch漏れ** — 非同期処理に適切なエラーハンドリングがあるか。エラーがサイレントに握りつぶされていないか
- **ユーザー向けエラーメッセージ** — エラー時にユーザーへの通知（toast等）が適切に行われているか

### Vue.js Patterns（詳細）

- **非同期レースコンディション** — Composable内の非同期関数が連続呼び出しされた場合、古いレスポンスで状態が上書きされないか。requestIdガードパターンで対策（→ `references/code-examples.md`）
- **UIガードとビジネスロジックガードの一致** — UIレベルのガード（`isClickable` computed等）だけでなく、イベントハンドラのビジネスロジック層でも同じ制約を担保しているか
- **暗黙のtruthyチェック** — `if (value)`による暗黙チェックで`null`・`undefined`・空文字が意図通りに処理されるか

### Test Quality（テストファイルが変更されている場合）

- **MSW使用** — APIモックはMSWを使用しているか。`vi.fn()`の直接モック乱用は避ける
- **FormDataを使うmutationテスト** — `FormData`を使うMutationのテストでAxiosアダプターをNode.js httpに設定しているか（`axios.defaults.adapter = 'http'`）（→ `references/code-examples.md`）
- **型安全なモック** — モック関数に適切な型が付いているか
- **テストケースの網羅性** — ローディング・エラー・成功状態のそれぞれをカバーしているか
- **テストデータの独立性** — テスト間で共有される可変なオブジェクトがないか

### Security（セキュリティ）

- **XSS対策** — `v-html`の使用時にサニタイズされているか。ユーザー入力を直接DOMに渡していないか
- **依存ライブラリの脆弱性** — 既知の脆弱性を持つライブラリ（例: `xlsx`）を使用していないか
- **機密情報のログ出力** — `console.*`等でAPIキー・トークン・パスワードを出力していないか

### Code Organization & DRY（詳細）

- **DRY原則** — 同一・類似のロジックが複数コンポーネント/composableに存在しないか
- **コンポーネント分割** — 1コンポーネントが複数の責務を持ちすぎていないか
- **マジックストリング** — 複数ファイルで使われる文字列リテラルを共有定数化しているか（→ `references/code-examples.md`）
- **ゲッター関数の二重呼び出し** — `computed`内でゲッター関数を複数回呼び出していないか（→ `references/code-examples.md`）
- **computed内クロージャ生成** — `computed`スコープ内で関数オブジェクトを定義すると再評価のたびに再生成される。composable本体スコープに抽出（→ `references/code-examples.md`）
- **状態リセットの対称性** — ファイル削除・変更・差替等の全パスで関連状態が適切にリセットされているか
- **イベントハンドラの不要な再代入** — 高頻度イベントハンドラで状態が変化しない場合も毎回代入が走っていないか
- **`@pages/`エイリアスの使用** — pages層内では`@pages/`エイリアスを使用（相対パスは規約違反）

---

## Red Flags - Never Do This

- 重要度インジケーターを省略
- actionableな修正案なしにフィードバック
- Core Checklistの項目をスキップ
- FSD index.ts直接importを見逃す
- features間の直接importを見逃す
- `any`/`enum`/`console.*`の使用を見逃す
- composable stateのreadonly保護漏れを見逃す
- `v-for`のindex keyを見逃す
- Floating Promiseを見逃す
- コードdiffなしに修正案を提示
