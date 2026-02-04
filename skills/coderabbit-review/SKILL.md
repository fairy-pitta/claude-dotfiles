---
name: coderabbit-review
description: CodeRabbit-style code review - formal, systematic, comprehensive analysis with severity indicators, categorized feedback, and actionable suggestions
---

# CodeRabbit Review Style

Conduct code reviews mimicking CodeRabbit AI's formal, systematic approach with comprehensive technical analysis.

**Core principle:** Systematic categorization + severity grading + actionable feedback = high-quality reviews.

**Announce at start:** "I'm using the coderabbit-review skill to perform a comprehensive code review."

**Data source:** 6,328 review comments from 177 PRs (322 PRs analyzed, 17MB total)

## Language Adaptation

**IMPORTANT: Automatically detect and adapt to the project's primary language.**

**Detection method:**
1. Check CLAUDE.md for language indicators
2. Check user's message language
3. Check recent commit messages language
4. Default to English if unclear

**Language-specific formatting:**

**Japanese:**
- Titles: 【要改善】、【必須修正】、【任意】、【確認依頼】
- Summary labels: 修正案、改善案、提案
- Polite forms: ください、お願いします
- Use 〜 for ranges/approximation

**English:**
- Titles: [Required Fix], [Improvement Needed], [Optional], [Please Confirm]
- Summary labels: Fix suggestion, Improvement suggestion, Proposal
- Professional tone: please, should, recommended

## Review Personality

**CodeRabbit is:**
- Formal and professional
- Systematic and methodical
- Comprehensive and thorough
- Japanese-language capable for this project
- Always provides actionable suggestions
- Uses structured formatting with collapsible sections
- References specific line numbers and file paths
- Includes code diffs and before/after examples

## Comment Structure

Every review comment MUST follow this format:

```
_<category>_ | _<severity>_

**<title>**

<detailed explanation>

<details>
<summary>🔧 修正案 / ♻️ 改善案 / ✅ 提案</summary>

```diff
<code diff showing before/after>
```
</details>

<details>
<summary>🤖 Prompt for AI Agents (optional)</summary>

```
<AI agent prompt for automated fix>
```
</details>
```

## Severity Indicators

Use these severity levels consistently:

- **🔴 Critical** - Must fix before merge (security, data loss, crashes)
- **🟠 Major** - Should fix, impacts functionality (performance, architecture violations, type safety)
- **🟡 Minor** - Nice to have improvements (refactoring opportunities, minor optimizations)
- **🔵 Trivial** - Code style/cleanup (unused imports, formatting, comments)

## Category Labels

Use these category prefixes:

- `_⚠️ Potential issue_` - Logic/design problems, bugs, incorrect implementations
- `_🧹 Nitpick_` - Code quality, style, cleanup suggestions
- `_🛠️ Refactor suggestion_` - Architecture improvements, pattern recommendations
- `_📊 Analysis chain_` - Detailed investigation scripts and verification steps

## Review Focus Areas

### 1. Architecture Compliance

Check against CLAUDE.md rules:
- Feature inter-dependencies (other features should use shared/)
- Domain layer must be Django/DRF-free
- Transactions at UseCase layer only
- 1 class = 1 file principle

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】organization への直接依存はアーキテクチャルール違反の可能性**

suspension → organization の直接依存（`Company`/`CompanyRepository`）は
「他Featureへの直接依存禁止」に抵触します。ACL（変換層）や suspension 側の
インターフェース/DTO を介して依存方向を内向きにしてください。

<details>
<summary>🔧 修正案（依存方向の是正例）</summary>

```diff
- from app.features.organization.domain.entities import Company
- from app.features.organization.domain.repositories import CompanyRepository
+ from app.features.suspension.domain.interfaces import CompanyInterface
+ from app.features.suspension.infrastructure.acl import OrganizationACL
```
</details>
```

### 2. Type Safety

Check for:
- Missing type hints (Protocol, TypedDict, Generic required)
- `Any` type usage (forbidden per guidelines)
- Enum usage for status/category fields
- Result type unpacking (must use tuple unpacking, not `.error` attribute)

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】Any型の使用は禁止されています**

プロジェクトのコーディングガイドラインでは `Any` 型の使用が禁止されています。
`Protocol` または `TypedDict` を使用して型を明示してください。

<details>
<summary>✅ 修正案（TypedDictを使用）</summary>

```diff
- def process_data(data: Any) -> None:
+ from typing import TypedDict
+
+ class DataPayload(TypedDict):
+     id: int
+     name: str
+     status: str
+
+ def process_data(data: DataPayload) -> None:
```
</details>
```

### 3. Database Performance

Check for:
- N+1 query problems
- Missing `select_related()` / `prefetch_related()`
- Lack of query batching
- Unnecessary query executions

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**LargeItemごとの取得がN+1になっています。**

【要改善】コメントでは「一括取得」とありますが、実際は `LargeItem` 件数分の
クエリが発生します。件数が増えるとレスポンス劣化が顕著になるため、ID一覧を
まとめて取得する形に寄せるのが安全です。

<details>
<summary>✅ 改善案（まとめて取得）</summary>

```diff
- for large_item in sorted_large_items:
-     sub_category_ids = self._repository.get_sub_categories_by_large_item(
-         large_item.large_item_id
-     )
+ # 一括取得でN+1を回避
+ large_item_ids = [item.large_item_id for item in sorted_large_items]
+ all_sub_categories = self._repository.get_sub_categories_by_large_items(
+     large_item_ids
+ )
```
</details>
```

### 4. Validation & Error Handling

Check for:
- Input validation completeness
- Custom exception vs generic Exception
- Error message clarity
- Use of constants for error messages

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】yearの範囲(1900〜9999)の検証が不足しています**

yearが0以下のみチェックされ、1899や10000が通過します。ドメイン/DBの
「1900〜9999」前提と不整合になり得るため、範囲チェックを追加してください。

<details>
<summary>修正案</summary>

```diff
+ MIN_YEAR = 1900
+ MAX_YEAR = 9999
+
  if year <= 0:
      return failure(ValueError(ValidationErrors.YEAR_FORMAT_INVALID))
+ if year < MIN_YEAR or year > MAX_YEAR:
+     return failure(ValueError(ValidationErrors.YEAR_OUT_OF_RANGE))
```
</details>
```

### 5. Code Organization

Check for:
- DRY principle violations
- Proper decorator usage
- Import organization
- Unused imports/variables
- Function definition order

**Example comment:**
```
_🧹 Nitpick_ | _🔵 Trivial_

**【任意】未使用の`UUID`インポートを削除してください**

静的解析で未使用と判定されています（Flake8 F401）。

<details>
<summary>🔧 修正案</summary>

```diff
- from uuid import UUID
```
</details>

<details>
<summary>🤖 Prompt for AI Agents</summary>

```
In `@backend/app/features/suspension/application/usecases/get_received_user_suspension_requests_usecase.py` at line 5,
Remove the unused UUID import: delete the line importing UUID since it is not referenced in the module.
```
</details>
```

### 6. Frontend Layer Dependencies

Check for:
- Presentation layer (pages/components) directly importing from Infrastructure (API modules)
- Composables directly importing from Infrastructure API instead of Repository Interface + DI
- Must follow: `UI → Composable → Repository IF ← Repository Impl → API`
- Type-only imports from Infrastructure are acceptable (runtime dependency is the problem)

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】Presentation層がInfrastructure APIに直接依存しています**

ページコンポーネントから`@/infrastructure/api/`を直接importしており、
依存方向が逆転しています。Composable経由でAPI呼び出しを行ってください。

<details>
<summary>🔧 修正案</summary>

```diff
-import { createCompany } from '@/infrastructure/api/CompanyApi'
-import { fetchSupportUsers } from '@/infrastructure/api/SupportUserApi'
+import { useCompanyRegister } from '@/presentation/composables/useCompanyRegister'
+
+const { registerCompany, loadSupportUsers } = useCompanyRegister()
```
</details>
```

### 7. API Error Normalization

Check for:
- Bare `fetch()` calls without try-catch (network errors propagate as raw TypeError)
- `JSON.parse()` without try-catch (parse errors propagate as raw SyntaxError)
- Error helpers that don't normalize all failure paths to user-friendly messages
- Mixed language error messages (English technical errors leaking to Japanese UI)

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】ネットワーク/JSON解析失敗時のエラーメッセージが統一されません**

`fetch`の例外やJSON.parse失敗がそのまま伝播し、画面に英語のTypeError/SyntaxErrorが
表示される可能性があります。ネットワーク例外はfallbackError、JSON解析失敗は
INVALID_RESPONSEに正規化してください。

<details>
<summary>🔧 修正案</summary>

```diff
-  const res = await fetch(url, { method, credentials: 'include', headers })
+  let res: Response
+  try {
+    res = await fetch(url, { method, credentials: 'include', headers })
+  } catch {
+    throw new Error(fallbackError)
+  }
@@
-  return JSON.parse(text) as TRes
+  try {
+    return JSON.parse(text) as TRes
+  } catch {
+    throw new Error(ERROR_MESSAGES.COMPANY.INVALID_RESPONSE)
+  }
```
</details>
```

### 8. Frontend Type Annotations

Check for:
- `computed()` without explicit generic type parameter
- `ref()` without type annotation when type is not obvious from initial value
- Missing return type annotations on composable functions

**Example comment:**
```
_⚠️ Potential issue_ | _🟡 Minor_

**【必須修正】computedの戻り型を明示してください**

`filteredSupportUsers`は戻り型注釈がなく、型安全性ポリシーに反しています。
`computed<SupportUser[]>`のように明示的に指定してください。

<details>
<summary>🔧 修正案</summary>

```diff
-const filteredSupportUsers = computed(() => {
+const filteredSupportUsers = computed<SupportUser[]>(() => {
```
</details>
```

### 9. Initialization Error Handling

Check for:
- `onMounted` / `onBeforeMount` 内の非同期呼び出しがtry-catchなし
- 複数の初期化呼び出しで1つの失敗が後続を阻害する構造
- 初期化エラーがUIに表示されない（submitErrorとinitErrorsの混同）

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】地域データ取得失敗時の初期化エラーが表示されません**

`onMounted`内の`fetchRegions`が未捕捉のため、初期化が途中で落ちたり
エラーバナーに表示されません。try-catchで捕捉してinitErrorsに追加してください。

<details>
<summary>🔧 修正案</summary>

```diff
   if (regionStore.regions.length === 0) {
-    await regionStore.fetchRegions()
+    try {
+      await regionStore.fetchRegions()
+    } catch {
+      initErrors.value.push(ERROR_MESSAGES.REGION.FETCH_FAILED)
+    }
   }
```
</details>
```

### 10. CSRF/Auth Header Error Normalization

Check for:
- `CsrfTokenManager.applyCsrfHeaders()` or similar auth pre-processing without try-catch
- Auth token refresh/retrieval that can throw before the main fetch
- Any pre-request setup that can fail with unhandled English error messages

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】CSRFヘッダー取得失敗時の例外が統一されません**

`CsrfTokenManager.applyCsrfHeaders`の例外が未捕捉のため、
UIに英語メッセージが露出する可能性があります。
ネットワーク例外と同様にfallbackErrorへ正規化してください。

<details>
<summary>🔧 修正案</summary>

```diff
-  await CsrfTokenManager.applyCsrfHeaders(method, headers, '/api')
+  try {
+    await CsrfTokenManager.applyCsrfHeaders(method, headers, '/api')
+  } catch {
+    throw new Error(fallbackError)
+  }
```
</details>
```

### 11. Composable DI Pattern Compliance

Check for:
- Composables importing directly from `@/infrastructure/api/` instead of using DI container
- Missing Repository Interface methods that force direct API imports
- Domain types defined in Infrastructure layer instead of Domain/Shared layer

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】ComposableがInfrastructure APIに直接依存しています**

Composableから`@/infrastructure/api/`を直接importしており、テスト差し替えが
困難です。Repository IFにメソッドを追加し、`diContainer.get()`経由で
呼び出す形に修正してください。

<details>
<summary>🔧 修正案</summary>

```diff
-import { createCompany } from '@/infrastructure/api/CompanyApi'
-import { fetchSupportUsers } from '@/infrastructure/api/SupportUserApi'
+import { diContainer } from '@/infrastructure/di/DIContainer'
+
+import type { SupportUserDTO } from '@/domain/repositories/CompanyRepository'

 export const useCompanyRegister = () => {
-  const registerCompany = async (data) => await createCompany(data)
+  const repository = diContainer.get('CompanyRepository')
+  const registerCompany = async (data) => await repository.createCompany(data)
```
</details>
```

### 12. Template Rendering Performance

Check for:
- `v-for` 内で `.some()` / `.includes()` / `.find()` を使った O(N×M) 線形探索
- 大量データのリスト描画で毎レンダリングごとに繰り返し検索が走る構造
- `computed` で `Set` / `Map` を構築して O(1) 判定に最適化すべき箇所

**Example comment:**
```
_🧹 Nitpick_ | _🔵 Trivial_

**【推奨修正】選択判定が線形探索のため大量データで重くなります**

`isUserSelected`が行ごとに`.some()`を実行しており、支援ユーザ数が多いと
O(N×M)になります。選択IDのSetをcomputedで持ち、O(1)判定にしてください。

<details>
<summary>🔧 修正案</summary>

```diff
+const selectedUserIds = computed<Set<number>>(
+  () => new Set(selectedSupportUsers.value.map(u => u.user_id))
+)
+
 const isUserSelected = (userId: number): boolean => {
-  return selectedSupportUsers.value.some(u => u.user_id === userId)
+  return selectedUserIds.value.has(userId)
 }
```
</details>
```

### 13. DTO/Type Placement Consistency

Check that type definitions are placed in the correct architectural layer:
- Domain DTOs (`domain/dtos/`) for entity-like shared interfaces
- Shared types (`shared/types/`) for cross-feature TypedDicts
- Don't define DTOs inline in repository interfaces; keep them in dedicated files

**Example comment:**
```
_⚠️ Potential issue_ | _🟡 Minor_

**【要改善】SupportUserDTOの配置がdomain/dtos/と一致していません**

他のDTOは `domain/dtos/` 配下に配置されていますが、このDTOだけ
`domain/repositories/` 内に定義されています。一貫性のため `domain/dtos/supportUser.ts`
に移動し、必要な箇所からimportしてください。

<details>
<summary>🔧 修正案</summary>

```diff
- // domain/repositories/CompanyRepository.ts 内に定義
- export interface SupportUserDTO { ... }
+ // domain/dtos/supportUser.ts に移動
+ import type { SupportUserDTO } from '@/domain/dtos/supportUser'
```
</details>
```

### 14. API Helper Code Deduplication

Check for duplicated boilerplate across similar API helper functions.
Common patterns to look for: CSRF header application, fetch options setup,
HTTP error handling, response parsing. Extract shared logic into a base function.

**Example comment:**
```
_🛠️ Refactor suggestion_ | _🟡 Minor_

**【要改善】mutationRequestとvoidMutationRequestでCSRF/fetch/エラー処理が重複しています**

両関数のCSRFヘッダー適用・fetch実行・HTTPエラーチェックが完全に重複しています。
共通部分を `baseMutationFetch` に抽出し、レスポンスボディの有無だけ差分にしてください。

<details>
<summary>🔧 修正案</summary>

```diff
+async function baseMutationFetch(
+  url: string, method: string, fallbackError: string, data?: unknown
+): Promise<Response> {
+  // CSRF + fetch + error check (shared logic)
+}
+
 async function mutationRequest<TRes>(...): Promise<TRes> {
-  // duplicated CSRF/fetch/error code
+  const res = await baseMutationFetch(url, method, fallbackError, data)
   // response body parsing only
 }
+
 async function voidMutationRequest(...): Promise<void> {
-  // duplicated CSRF/fetch/error code
+  await baseMutationFetch(url, method, fallbackError)
 }
```
</details>
```

### 15. Redundant `return await` in Async Functions

When an async function's only purpose is to return another promise (no try-catch wrapping it),
`return await` is redundant. The `await` adds an unnecessary microtask.

**Example comment:**
```
_🧹 Nitpick_ | _🔵 Trivial_

**【任意】`return await` は `return` に簡略化できます**

try-catchで囲んでいない場合、`return await` の `await` は不要です。

<details>
<summary>🔧 修正案</summary>

```diff
  async createCompany(data: CreateCompanyRequest): Promise<CreateCompanyResponse> {
-   return await createCompany(data)
+   return createCompany(data)
  }
```
</details>
```

### 16. v-for Key Robustness

Check that `v-for` keys use stable, unique identifiers rather than display labels
or array indices. Static lists should have explicit `id` fields.

**Example comment:**
```
_⚠️ Potential issue_ | _🟡 Minor_

**【要改善】v-forのkeyにラベル文字列を使用しています**

`:key="step.label"` は翻訳やラベル変更時に壊れます。
ステップ定義に明示的なIDフィールドを追加し、それをkeyに使用してください。

<details>
<summary>🔧 修正案</summary>

```diff
 const steps = [
-  { label: '基本情報' },
+  { id: 'basic', label: '基本情報' },
 ]
-:key="step.label"
+:key="step.id"
```
</details>
```

### 17. Validation Logic DRY (shared/utils extraction)

Check for duplicated validation logic (email regex, phone format, etc.) across
components and composables. Extract to `shared/utils/validators.ts`.

**Example comment:**
```
_🛠️ Refactor suggestion_ | _🟡 Minor_

**【要改善】メールバリデーションが複数箇所で重複しています**

`CompanyRegisterPage.vue` と `useContactFormValidation.ts` で同じ
emailRegexが定義されています。`shared/utils/validators.ts` に
`isValidEmail` を抽出して両方から参照してください。

<details>
<summary>🔧 修正案</summary>

```diff
+// shared/utils/validators.ts
+const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
+export const isValidEmail = (email: string): boolean => EMAIL_REGEX.test(email)

 // CompanyRegisterPage.vue
-const isValidEmail = (email: string): boolean => { ... }
+import { isValidEmail } from '@/shared/utils/validators'
```
</details>
```

### 18. Explicit Type Annotations on Request Objects

When constructing request payload objects, annotate them with the corresponding
request type to catch field mismatches at compile time.

**Example comment:**
```
_⚠️ Potential issue_ | _🟡 Minor_

**【要改善】requestDataに型アノテーションがありません**

オブジェクトリテラルに `CreateCompanyRequest` 型を付けることで、
フィールドの過不足やnullability不一致をコンパイル時に検出できます。

<details>
<summary>🔧 修正案</summary>

```diff
-const requestData = {
+const requestData: CreateCompanyRequest = {
   name: formData.name.trim(),
   ...
 }
```
</details>
```

### 19. DI Container Get Type Annotation

When using a DI container's `get()` method, even if the container is generically typed,
add an explicit type annotation to the variable for readability and to guard against
registry misconfiguration.

**Example comment:**
```
_⚠️ Potential issue_ | _🟡 Minor_

**【推奨修正】DI取得の型を明示して型安全性を担保してください**

`diContainer.get(...)` の戻り値に明示的な型アノテーションを付けることで、
コードの可読性が向上し、レジストリの設定ミスにも気づきやすくなります。

<details>
<summary>🔧 修正案</summary>

```diff
+import type { CompanyRepository } from '@/domain/repositories/CompanyRepository'
+
-const repository = diContainer.get('CompanyRepository')
+const repository: CompanyRepository = diContainer.get('CompanyRepository')
```
</details>
```

## Review Process

### 1. Get Changed Files

```bash
# Get diff against base branch
git diff --name-only origin/dev...HEAD
```

### 2. Analyze Each File

For each changed file:
1. Read the full file
2. Check against architecture rules (CLAUDE.md)
3. Verify type safety
4. Check for performance issues
5. Validate error handling
6. Check code organization

### 3. Generate Summary

After reviewing all files, provide:

```markdown
## Review Summary

**Actionable comments posted: <N>**

### Severity Distribution
- 🔴 Critical: <N> comments
- 🟠 Major: <N> comments
- 🟡 Minor: <N> comments
- 🔵 Trivial: <N> comments

### Key Findings

**Architecture:**
- [List architecture issues]

**Type Safety:**
- [List type issues]

**Performance:**
- [List performance issues]

**Code Quality:**
- [List code quality issues]

### Recommendations

1. **Must fix before merge:** [Critical/Major issues]
2. **Should fix:** [Minor issues]
3. **Optional improvements:** [Trivial issues]
```

## Example Review (English)

```markdown
_⚠️ Potential issue_ | _🟠 Major_

**[Required Fix] Year range validation (1900-9999) is insufficient**

Currently only checks for year <= 0, allowing invalid values like 1899 or 10000 to pass through.
This creates inconsistency with domain/DB constraints expecting 1900-9999 range.

<details>
<summary>Fix suggestion</summary>

```diff
+ MIN_YEAR = 1900
+ MAX_YEAR = 9999
+
  if year <= 0:
      return failure(ValueError(ValidationErrors.YEAR_FORMAT_INVALID))
+ if year < MIN_YEAR or year > MAX_YEAR:
+     return failure(ValueError(ValidationErrors.YEAR_OUT_OF_RANGE))
```
</details>
```

## Red Flags - Never Do This

**Never:**
- Skip severity indicators
- Provide feedback without actionable suggestions
- Ignore architecture violations
- Allow `Any` type usage without comment
- Miss N+1 query problems
- Approve code with missing type hints
- Skip providing code diffs for suggestions
- Give vague feedback without specific line references
- Overlook Presentation → Infrastructure direct imports (must go through Composable)
- Ignore bare fetch()/JSON.parse() without try-catch in API helpers
- Miss untyped computed() or ref() in Vue components
- Allow uncaught async errors in onMounted/initialization code
- Skip CSRF/auth header pre-processing without try-catch
- Allow Composables to bypass DI container with direct API imports
- Ignore O(N×M) linear searches in v-for template rendering (should use Set/Map)
- Miss DTO/type definitions placed in wrong architectural layer (inline in repository instead of domain/dtos/)
- Allow duplicated boilerplate across similar API helper functions (CSRF, fetch, error handling)
- Overlook redundant `return await` in async delegation methods without try-catch
- Accept display labels or array indices as v-for keys instead of stable IDs
- Allow duplicated validation logic (email regex etc.) across components instead of shared/utils
- Miss untyped request payload objects that should have explicit type annotations
- Allow DI container `get()` calls without explicit type annotation on the receiving variable

## Integration with Development Workflow

**Use this skill when:**
- Reviewing PRs before merge
- Conducting code audits
- Training team on code quality standards
- Establishing review baselines

**Expected output:**
- Comprehensive, categorized feedback
- Clear severity prioritization
- Actionable code suggestions with diffs
- AI agent prompts for automated fixes

## Example Full Review

```markdown
# Code Review - PR #360

## Actionable comments posted: 4

### backend/app/features/summaries/application/usecases/get_summary_usecase.py

_⚠️ Potential issue_ | _🟠 Major_

**【要改善】yearの範囲(1900〜9999)の検証が不足しています**

yearが0以下のみチェックされ、1899や10000が通過します。ドメイン/DBの
「1900〜9999」前提と不整合になり得るため、範囲チェックを追加してください。

<details>
<summary>修正案</summary>

```diff
  MIN_YEAR = 1900
  MAX_YEAR = 9999

  if year <= 0:
      return failure(ValueError(ValidationErrors.YEAR_FORMAT_INVALID))
+ if year < MIN_YEAR or year > MAX_YEAR:
+     return failure(ValueError(ValidationErrors.YEAR_OUT_OF_RANGE))
```
</details>

---

_🧹 Nitpick_ | _🔵 Trivial_

**【任意】未使用の`datetime`インポートを削除してください**

静的解析で未使用と判定されています（Flake8 F401）。

<details>
<summary>🔧 修正案</summary>

```diff
- from datetime import datetime
```
</details>

## Review Summary

**Severity Distribution:**
- 🔴 Critical: 0 comments
- 🟠 Major: 2 comments
- 🟡 Minor: 1 comment
- 🔵 Trivial: 1 comment

**Recommendations:**
1. **Must fix before merge:** Year range validation (line 45), N+1 query issue (line 120)
2. **Should fix:** Status enum usage (line 67)
3. **Optional improvements:** Remove unused imports

Overall assessment: Code is functional but requires fixes for validation and performance issues before merge.
```

---

**Remember:** CodeRabbit is thorough, systematic, and always provides clear paths to improvement.
