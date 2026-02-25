# Frontend CodeRabbit - コード例示集

## FSD Architecture

### index.ts（公開API）経由のimport

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

### Composables → Repository IF を介さず実装に直結はNG

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

---

## Type Safety

### enum禁止 → const + as const

```typescript
// ❌ Bad
enum Status { Active = 'active', Inactive = 'inactive' }

// ✅ Good
const Status = { Active: 'active', Inactive: 'inactive' } as const
type Status = typeof Status[keyof typeof Status]
```

---

## TanStack Vue Query

### QueryKey Factory パターン

```typescript
// ✅ Good: QueryKey Factory
export const companyKeys = {
  all: ['companies'] as const,
  list: (filters: CompanyFilter) => [...companyKeys.all, 'list', filters] as const,
  detail: (id: number) => [...companyKeys.all, 'detail', id] as const,
}
```

---

## State Management

### composable singleton の readonly 保護

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

---

## Error Handling

### エラーメッセージ直書き禁止

```typescript
// ❌ Bad
throw new Error('ファイルサイズが上限を超えています')

// ✅ Good
throw new AppError(ERROR_CATALOG.FILE.SIZE_EXCEEDED)
```

### 非対称な disabled 状態

```typescript
// ❌ Bad: period viewにはguardがあってoverlap viewにはない
// period view
<Button :disabled="isUploading" @click="handleUpload">アップロード</Button>

// overlap view（guardなし）
<Button @click="handleUpload">アップロード</Button>

// ✅ Good: 全ボタンに対称にguardを付ける
<Button :disabled="isUploading" @click="handleUpload">アップロード</Button>
```

---

## Vue.js Patterns

### v-for の :key に index を使わない

```html
<!-- ❌ Bad -->
<tr v-for="(item, index) in items" :key="index">

<!-- ✅ Good -->
<tr v-for="item in items" :key="item.id">
```

### 非同期レースコンディション対策

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

---

## Test Quality

### FormData を使う mutation テスト

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

---

## Unused Code Detection

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

---

## Code Organization & DRY

### マジックストリング → 共有定数化

```typescript
// ❌ Bad: 複数ファイルで文字列リテラルを直書き
if (displayType === 'transitive') { ... }

// ✅ Good: 共有定数ファイルに定義
// types.ts
export const DISPLAY_TYPES = { TRANSITIVE: 'transitive' } as const
// 利用側
if (displayType === DISPLAY_TYPES.TRANSITIVE) { ... }
```

### ゲッター関数の二重呼び出し

```typescript
// ❌ Bad: computedの再評価のたびに複数回呼び出し
const label = computed(() => {
  if (accountTitleIndex() !== null) {
    return items[accountTitleIndex() % 2]  // 2回目の呼び出し
  }
})

// ✅ Good: ローカル変数に格納してから使用
const label = computed(() => {
  const index = accountTitleIndex()
  if (index !== null) {
    return items[index % 2]
  }
})
```

### computed 内クロージャ生成の回避

```typescript
// ❌ Bad: computedの再評価のたびに関数が再生成される
const result = computed(() => {
  const getLabel = (v: string) => v.toUpperCase()
  return items.value.map(getLabel)
})

// ✅ Good: composable本体スコープに抽出
const getLabel = (v: string) => v.toUpperCase()
const result = computed(() => items.value.map(getLabel))
```
