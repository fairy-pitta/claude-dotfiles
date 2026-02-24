---
name: frontend-coderabbit
description: Frontend専用 CodeRabbit-style code review - Vue 3 + TypeScript + FSD (Feature-Sliced Design) + TanStack Queryの観点で体系的・網羅的にレビュー。Djangoバックエンドは対象外。
---

# Frontend CodeRabbit Review

Vue 3 + TypeScript + FSD (Feature-Sliced Design)のフロントエンドコードをCodeRabbitスタイルで体系的にレビューする。

**Announce at start:** "I'm using the frontend-coderabbit skill to perform a comprehensive frontend code review."

**Data source:** 394 frontend inline comments from 33 PRs (recent 40 PRs analyzed)

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

## Review Focus Areas

### 1. FSD Architecture Compliance（FSDアーキテクチャ準拠）`[最多頻出: FSD 21回, import 15回, スライス 9回]`

依存方向: `app → pages → features → entities → shared`（上位→下位のみ）

**1-1. index.ts（公開API）経由のimport必須** `[最多指摘項目]`

外部スライスの内部モジュールへの直接importは絶対NG。必ず各スライスの`index.ts`（公開API）経由でimportすること。

```typescript
// ❌ Bad: スライス内部モジュールへの直接import
import { CompanyApi } from '@entities/company/api/companyApi'
import { useLoginMutation } from '@features/auth/login/model/loginMutations'
import { validateAmount } from '@features/journal/lib/validators'

// ✅ Good: index.ts経由のimport
import { CompanyApi } from '@entities/company'
import { useLoginMutation } from '@features/auth'
import { validateAmount } from '@features/journal'
```

```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】FSDの公開API（index.ts）経由のimportに戻してください**

`@features/file-import/lib/validators`への直接importはFSD規約違反です。
`@features/file-import`（index.ts）経由でアクセスしてください。

<details>
<summary>🔧 修正案</summary>

```diff
- import { validateFileSize } from '@features/file-import/lib/validators'
+ import { validateFileSize } from '@features/file-import'
```
</details>
```

**1-2. pages層からのfeatures内部参照禁止**

`pages/`層は`features/`の`index.ts`のみを参照できる。`features/{slice}/model/`, `features/{slice}/lib/`等への直接参照はNG。

**1-3. features間の直接import禁止** `[アーキテクチャ根幹]`

features間の直接import（型importも含む）は禁止。共有したい型・ロジックは`entities/`または`shared/`に昇格させること。

**1-4. entities間の`@x`パターン** - entities間は`import type`のみ許可。ランタイムimportは禁止。

**1-5. FSDエイリアス必須** - 相対パスではなく`@app/`, `@pages/`, `@features/`, `@entities/`, `@shared/`のエイリアスを使用

**1-6. 3+スライスから使用される機能の昇格** - 3スライス以上から参照されるコードは上位層に昇格必須

**1-7. Composables→Repository IFを介さず実装に直結はNG** `[新観点]`

ComposablesがhttpClient等に直結すると、FSDの`Composables → Repository IF`の依存方向に反する。

```typescript
// ❌ Bad: httpClient直結
import { httpClient } from '@shared/api'
export function useUploadJournal() {
  return useMutation({ mutationFn: (data) => httpClient.post('/journal', data) })
}

// ✅ Good: Repository IF経由
import type { JournalUploadRepository } from '@entities/journal'
export function useUploadJournal(repo: JournalUploadRepository) {
  return useMutation({ mutationFn: (data) => repo.upload(data) })
}
```

### 2. Type Safety（型安全性）`[型: 40回 - 最多頻出キーワード]`

- **`any`型禁止** `[10回]` - `any`は禁止。`unknown`/`never`/ジェネリクス/型ガードで代替
- **`enum`禁止** - TypeScriptの`enum`は禁止。constオブジェクト + `as const` + `typeof`で代替
  ```typescript
  // ❌ Bad
  enum Status { Active = 'active', Inactive = 'inactive' }

  // ✅ Good
  const Status = { Active: 'active', Inactive: 'inactive' } as const
  type Status = typeof Status[keyof typeof Status]
  ```
- **`console.*`禁止** - `console.log/warn/error`等は禁止。エラーは4層パイプライン経由
- **`<script setup lang="ts">`必須** - `<script setup>`の`lang="ts"`省略禁止
- **型アサーション`as`の使用** - `as`による強制キャストが型安全でないケースに注意。型ガードで代替推奨
- **Floating Point Number** - 金額に浮動小数点演算を直接使わない。`Amount`型（branded integer）経由

### 3. TanStack Vue Query（サーバー状態管理）

- **QueryKey Factoryパターン** `[Query: 5回]` - QueryKeyは必ずFactoryパターンで定義。マスターデータは`['master', ...]` prefix必須
  ```typescript
  // ✅ Good: QueryKey Factory
  export const companyKeys = {
    all: ['companies'] as const,
    list: (filters: CompanyFilter) => [...companyKeys.all, 'list', filters] as const,
    detail: (id: number) => [...companyKeys.all, 'detail', id] as const,
  }
  ```
- **QueryKeyに`undefined`を渡さない** - `undefined`を含むQueryKeyはキャッシュ汚染の原因。デフォルト値を設定
- **Pinia非推奨（サーバー状態の二重管理禁止）** `[3回]` - サーバー状態をPiniaとTanStack Queryの両方で管理しない。サーバー状態はTanStack Queryに集約
- **楽観的更新禁止（仕訳Mutation）** - 仕訳関連のMutationで楽観的更新は禁止。冪等キー必須
- **Mutation後のinvalidateQueries** - Mutationの`onSuccess`で関連QueryKeyを`invalidateQueries`しているか

### 4. State Management（クライアント状態管理）

- **composable singletonのreadonly保護** `[readonly: 3回]` - module-levelのrefをそのまま公開しない。`readonly()`でラップして外部から直接書き込まれないようにする
  ```typescript
  // ❌ Bad: 生refを公開
  const selectedMonth = ref<string | null>(null)
  export function useSelectedMonth() {
    return { selectedMonth }
  }

  // ✅ Good: readonlyで保護
  const _selectedMonth = ref<string | null>(null)
  export function useSelectedMonth() {
    return {
      selectedMonth: readonly(_selectedMonth),
      setSelectedMonth: (v: string) => { _selectedMonth.value = v }
    }
  }
  ```
- **`computed`の使用** - テンプレート内の複雑な条件式は`computed`に切り出す

### 5. Error Handling（エラーハンドリング）`[エラー: 25回]`

- **エラーメッセージ直書き禁止** - エラーメッセージを文字列リテラルで直書きせず、カタログ定数経由
  ```typescript
  // ❌ Bad
  throw new Error('ファイルサイズが上限を超えています')

  // ✅ Good
  throw new AppError(ERROR_CATALOG.FILE.SIZE_EXCEEDED)
  ```
- **4層エラーパイプライン** - `shared → entities → features → pages`の順でエラーを処理。各層のエラーは適切な型に変換して上位に伝播
- **try-catch漏れ** - 非同期処理に適切なエラーハンドリングがあるか。エラーがサイレントに握りつぶされていないか
- **ユーザー向けエラーメッセージ** - エラー時にユーザーへの通知（toast等）が適切に行われているか

### 6. Vue.js Patterns（Vueパターン）

- **`v-for`の`:key`安定性** - `v-for`の`:key`にarray indexを使用していないか。`id`等の安定した識別子を使用
  ```html
  <!-- ❌ Bad -->
  <tr v-for="(item, index) in items" :key="index">

  <!-- ✅ Good -->
  <tr v-for="item in items" :key="item.id">
  ```
- **非同期レースコンディション** - Composable内の非同期関数が連続呼び出しされた場合、古いレスポンスで状態が上書きされないか。requestIdガードパターンで対策
  ```typescript
  const latestRequestId = ref(0)
  async function fetchDetails(params: Params) {
    const requestId = ++latestRequestId.value
    try {
      const response = await api.getData(params)
      if (requestId !== latestRequestId.value) return  // 古いリクエストは無視
      data.value = response.data
    } catch (e) {
      if (requestId !== latestRequestId.value) return
      error.value = e
    }
  }
  ```
- **Floating Promises** - `async`関数を`await`も`void`もなしに呼び出していないか。意図的なfire-and-forgetは`void`を明示
- **UIガードとビジネスロジックガードの一致** - UIレベルのガード（`isClickable` computed等）だけでなく、イベントハンドラのビジネスロジック層でも同じ制約を担保しているか
- **暗黙のtruthyチェック** - `if (value)`による暗黙チェックで`null`・`undefined`・空文字が意図通りに処理されるか。型に応じて`value != null`等の明示的チェックを推奨

### 7. Test Quality（テスト品質）`[テスト: 18回]`

- **MSW使用** - APIモックはMSWを使用しているか。`vi.fn()`の直接モック乱用は避ける
- **Vitestスタイル** - `describe/it/expect`の構成が適切か
- **FormDataを使うmutationテスト** - `FormData`を使うMutationのテストでAxiosアダプターをNode.js httpに設定しているか（`axios.defaults.adapter = 'http'`）
- **型安全なモック** - モック関数に適切な型が付いているか
- **テストケースの網羅性** - ローディング状態・エラー状態・成功状態のそれぞれをカバーしているか
- **テストデータの独立性** - テスト間で共有される可変なオブジェクトがないか

```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】FormDataを使うmutationテストでAxiosアダプターの設定が必要です**

Node.js環境でFormDataを使うAxiosリクエストをテストする場合、
`axios.defaults.adapter = 'http'`の設定が必要です。

<details>
<summary>🔧 修正案</summary>

```diff
+ import axios from 'axios'
+ axios.defaults.adapter = 'http'  // Node.js httpアダプターを使用

  it('ファイルアップロードが成功する', async () => {
```
</details>
```

### 8. Security（セキュリティ）

- **XSS対策** - `v-html`の使用時にサニタイズされているか。ユーザー入力を直接DOMに渡していないか
- **依存ライブラリの脆弱性** - 既知の脆弱性を持つライブラリ（例: `xlsx`）を使用していないか。`exceljs`等の安全な代替への移行を推奨
- **機密情報のログ出力** - `console.*`等でAPIキー・トークン・パスワードを出力していないか

### 9. Unused Code Detection（未使用コード）

- 呼び出されていないcomposable・関数・コンポーネント
- 未使用のimport（特にFSD違反のimportを削除した後の残骸）
- 参照されていない型定義・定数
- `barrel-only`なindex.tsから直接パスに変更された後の未参照エクスポート

```
_🧹 Nitpick_ | _🟡 Minor_

**【要改善】未使用の`generateMonthKey`を削除してください**

`generateMonthKey`はコードベース内のどこからも呼び出されていません。
内部で使用している`isValidAccountingMonth`も連鎖的に未使用になります。

<details>
<summary>🔧 修正案</summary>

```diff
- export function generateMonthKey(fiscalYear: number, month: number): string { ... }
- function isValidAccountingMonth(month: number): boolean { ... }
```
</details>
```

### 10. Code Organization & DRY

- **DRY原則** - 同一・類似のロジックが複数コンポーネント/composableに存在しないか
- **コンポーネント分割** - 1コンポーネントが複数の責務を持ちすぎていないか
- **`@pages/`エイリアスの使用** - pages層内では`@pages/`エイリアスを使用（相対パスは規約違反）
- **ルーター設定** - v2プレフィックス付きルート名など、ルート名の命名一貫性

### 11. Syntax & Basic Quality（構文・基本品質）

- **TypeScript構文エラー** - 型エラー・未解決の型不一致
- **マージコンフリクトマーカー** - `<<<<<<<`が残っていないか
- **`<script setup lang="ts">`の省略** - `lang="ts"`の省略は禁止
- **SFCの構造** - `<template>` → `<script setup lang="ts">` → `<style scoped>`の順

---

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^frontend/"
```

### 2. Analyze Each File

各frontendファイルに対して以下を確認:
1. FSD Architecture Compliance（index.ts経由, 依存方向, features間import, ComposablesとRepository IFの関係）
2. Type Safety（any禁止, enum禁止, console禁止, branded型）
3. TanStack Vue Query（QueryKey Factory, Pinia非推奨, 楽観更新）
4. State Management（readonly保護, composable singleton）
5. Error Handling（カタログ定数, 4層パイプライン）
6. Vue.js Patterns（v-for key, レースコンディション, Floating Promise）
7. Test Quality（MSW, FormData axios adapter, 型安全モック）
8. Security（XSS, 脆弱ライブラリ）
9. Unused Code Detection
10. Code Organization & DRY
11. Syntax & Basic Quality

### 3. Generate Summary

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

## Red Flags - Never Do This

- 重要度インジケーターを省略
- actionableな修正案なしにフィードバック
- FSD index.ts直接importを見逃す
- `any`/`enum`/`console.*`の使用を見逃す
- composable stateのreadonly保護漏れを見逃す
- v-forのindex keyを見逃す
- 非同期レースコンディションを見逃す
- Floating Promiseを見逃す
- コードdiffなしに修正案を提示
- features間の直接importを見逃す
