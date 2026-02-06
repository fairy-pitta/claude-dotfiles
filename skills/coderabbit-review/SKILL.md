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

Review Focus Areas are organized into 5 groups (A〜E).
Review is performed one group at a time across all changed files (5-pass approach).

---

### Group A: 型安全性 (Type Safety)

#### 1. Any型禁止

Check for:
- Missing type hints (Protocol, TypedDict, Generic required)
- `Any` type usage (forbidden per guidelines)
- Enum usage for status/category fields

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

#### 2. レイヤー間の型一貫性

Check for:
- Same concept using different types across layers (e.g. `year` as `str` in View but `int` in UseCase)
- Type conversion not happening at the boundary (Serializer/View layer)
- Inconsistent field types between DTO, Entity, and API response

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】yearの型がレイヤー間で不一致です**

View層では `str` 型で受け取っていますが、UseCase層では `int` 型を期待しています。
Serializer/View層で型変換を行い、UseCase以降は `int` 型に統一してください。

<details>
<summary>🔧 修正案</summary>

```diff
  # View layer: convert at boundary
- year = request.data.get("year")  # str
+ year = int(request.data.get("year"))  # int
  result, error = usecase.execute(GetSummaryRequest(year=year))
```
</details>
```

#### 3. Frontend型アノテーション

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

#### 4. リクエスト型明示

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

#### 5. DI Container Get型明示

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

#### 6. Django統合時のAny回避

Django Model/Manager統合時にAnyを使わないパターン。
`**kwargs: Any` を `TypedDict` + `Unpack` で型安全にする。

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】Djangoオーバーライドメソッドの**kwargs: Anyを型安全にしてください**

`Model.save()` や `create_user()` の `**kwargs: Any` は
`TypedDict` + `Unpack` で置き換えることでアプリ側の型安全性を確保できます。

<details>
<summary>🔧 修正案</summary>

```diff
+ from typing import TypedDict, Unpack
+
+ class SaveKwargs(TypedDict, total=False):
+     force_insert: bool
+     force_update: bool
+     update_fields: list[str] | None
+
- def save(self, **kwargs: Any) -> None:
+ def save(self, **kwargs: Unpack[SaveKwargs]) -> None:
```
</details>
```

---

### Group B: アーキテクチャ・配置 (Architecture & Placement)

#### 7. アーキテクチャ準拠

Check against CLAUDE.md rules:
- Feature inter-dependencies (other features should use shared/)
- Domain layer must be Django/DRF-free
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

#### 8. FEレイヤー依存

Check for:
- Presentation layer (pages/components) directly importing from Infrastructure (API modules)
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
+import { useCompanyRegister } from '@/presentation/composables/useCompanyRegister'
+
+const { registerCompany, loadSupportUsers } = useCompanyRegister()
```
</details>
```

#### 9. Composable DIパターン準拠

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
+import { diContainer } from '@/infrastructure/di/DIContainer'
+
 export const useCompanyRegister = () => {
-  const registerCompany = async (data) => await createCompany(data)
+  const repository = diContainer.get('CompanyRepository')
+  const registerCompany = async (data) => repository.createCompany(data)
```
</details>
```

#### 10. DTO配置の一貫性

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

#### 11. ファイル配置の適切性

Check that code is placed in the correct location:
- Shared utilities belong in `shared/` not inside a feature
- Enums belong in `domain/enums/`
- Error constants belong in `shared/constants/`
- Types used by 3+ features must be in `shared/types/`
- **Request/Result dataclasses belong in `types/` directory, not inline in usecase files**

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】shared配下に配置すべきコードがfeature内にあります**

このユーティリティは3つ以上のfeatureから参照されています。
`shared/` 配下の適切な場所に移動してください。

<details>
<summary>🔧 修正案</summary>

```diff
- // features/organization/utils/date_helper.py
+ // shared/utils/date_helper.py
```
</details>
```

**Example comment (Request型の配置):**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】Request型はtypes/配下に配置してください**

`ChangePasswordRequest` がusecaseファイル内に定義されていますが、
プロジェクトの慣例では `types/` ディレクトリに配置します。
他のfeatureと統一するため、`types/password.py` 等に移動してください。

参考: `organization/types/company.py`, `accounting/types/assignment.py`

<details>
<summary>🔧 修正案</summary>

```diff
- # usecases/change_password_usecase.py 内に定義
- @dataclass(frozen=True)
- class ChangePasswordRequest:
-     user_id: int
-     current_password: str
-     new_password: str

+ # types/password.py に移動
+ from app.features.user.types import ChangePasswordRequest
```
</details>
```

#### 12. Result型タプルアンパック

Result型は必ずタプルアンパックで受け取る。
`.error` 属性アクセスや `result[0]`/`result[1]` のインデックスアクセスは禁止。

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】Result型をインデックスアクセスで使用しています**

`result[0]`, `result[1]` のインデックスアクセスは可読性が低く、
プロジェクトルールに反しています。タプルアンパックで受け取ってください。

<details>
<summary>🔧 修正案</summary>

```diff
- result = usecase.execute(request)
- if result[1] is not None:
-     return ApiResponse.error(result[1])
- return ApiResponse.success(result[0])
+ value, error = usecase.execute(request)
+ if error is not None:
+     return ApiResponse.error(error)
+ return ApiResponse.success(value)
```
</details>
```

#### 13. トランザクション境界

Transactions must be managed at UseCase layer only.
Repository layer must NOT contain `transaction.atomic()`.
`select_for_update` requires a transaction to be active.

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】Repository層にtransaction.atomic()が配置されています**

トランザクション管理はUseCase層のみで行うルールです。
Repository層から `transaction.atomic()` を除去し、UseCase側で管理してください。

<details>
<summary>🔧 修正案</summary>

```diff
  # UseCase layer
+ from django.db import transaction
+
  def execute(self, request):
+     with transaction.atomic():
          self._repository.update(...)
          self._repository.create(...)

  # Repository layer
- from django.db import transaction
  def update(self, entity):
-     with transaction.atomic():
-         model.save()
+     model.save()
```
</details>
```

---

### Group C: エラーハンドリング・セキュリティ (Error Handling & Security)

#### 14. バリデーション・エラーハンドリング

Check for:
- Input validation completeness
- Custom exception vs generic Exception
- Error message clarity and use of constants
- Internal error information leaking to users (security concern)
- UseCase層でエラー内容を握り潰さず、View層で外部向けメッセージに変換

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

#### 15. APIエラー正規化

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
```
</details>
```

#### 16. 初期化エラーハンドリング

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

#### 17. CSRF/Auth正規化

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

#### 18. Serializerの機密フィールド設定

Check for:
- Password fields without `write_only=True` (can leak in serialized responses)
- Token/secret fields exposed in API responses
- Sensitive data that should never be returned to clients

**Example comment:**
```
_⚠️ Potential issue_ | _🟡 Minor_

**【推奨修正】パスワードフィールドに `write_only=True` を追加**

パスワードフィールドはリクエスト専用であり、レスポンスに含めるべきではありません。
`write_only=True` を指定することで、シリアライズ時にパスワードが誤って漏洩するリスクを防げます。

<details>
<summary>🛡️ 修正案</summary>

```diff
-    current_password = serializers.CharField(required=True)
-    new_password = serializers.CharField(required=True)
+    current_password = serializers.CharField(required=True, write_only=True)
+    new_password = serializers.CharField(required=True, write_only=True)
```
</details>
```

#### 19. DB変更後のオブジェクト同期

Check for:
- Using in-memory objects after DB update without `refresh_from_db()`
- Session auth hash updates with stale user objects
- Cache invalidation issues after model saves

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】DB更新後のオブジェクトを同期してください**

UseCaseでDB上のパスワードは更新されますが、`request.user`は古いハッシュのままです。
`update_session_auth_hash()` は渡されたuserオブジェクトのパスワードでセッションハッシュを
生成するため、このままだと次リクエストでセッションが破棄されます。

<details>
<summary>修正案</summary>

```diff
+    request.user.refresh_from_db()
     update_session_auth_hash(request, request.user)
```
</details>
```

#### 20. ビジネスロジック計算検証

Check for:
- Calculation logic matching business specifications
- Edge cases: closing month, starting date on last day of month, leap years
- Accounting month (`YYYY-MM`) format correctness including special month 13

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】期首日(starting_date)を考慮した月計算が不足しています**

会計月の算出で `closing_month` は参照されていますが、
`starting_date` が1日以外の場合に月がズレる可能性があります。
エッジケースのテストも追加してください。

<details>
<summary>🔧 修正案</summary>

```diff
  def calculate_accounting_month(date, closing_month, starting_date):
+     # starting_date考慮: 期首日より前の日付は前月に属する
+     if date.day < starting_date:
+         date = date - relativedelta(months=1)
      relative_month = (date.month - closing_month - 1) % 12 + 1
```
</details>
```

---

### Group D: パフォーマンス (Performance)

#### 21. DBパフォーマンス

Check for:
- N+1 query problems
- Missing `select_related()` / `prefetch_related()`
- Lack of query batching (`bulk_create` / `bulk_update`)
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

#### 22. テンプレート描画パフォーマンス

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

#### 23. 冗長な return await

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

---

### Group E: コード品質・DRY (Code Quality & DRY)

#### 24. コード構成

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

#### 25. APIヘルパー重複排除

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

#### 26. バリデーションDRY

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

#### 28. v-forキー堅牢性

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

#### 29. デッドコード・未使用変数

Check for:
- Unused imports, variables, functions, type definitions
- Dead code paths that can never be reached
- Commented-out code blocks
- These should be caught in self-review

**Example comment:**
```
_⚠️ Potential issue_ | _🟡 Minor_

**【必須修正】未使用の型定義が残っています**

`CompanyFilterType` は定義されていますが、どこからも参照されていません。
デッドコードはセルフレビューで弾いてください。削除をお願いします。

<details>
<summary>🔧 修正案</summary>

```diff
- type CompanyFilterType = {
-   name: string
-   region: string
- }
```
</details>
```

#### 27. エラーメッセージ定数の一貫性

Check for:
- Hardcoded values in error messages that should reference constants
- Inconsistent use of placeholders across similar messages
- Magic numbers that duplicate values from domain constants

**Example comment:**
```
_🧹 Nitpick_ | _🔵 Trivial_

**PASSWORD_TOO_WEAK メッセージ内の「8文字以上」を定数参照に修正**

`PASSWORD_TOO_WEAK` に「8文字以上」がハードコードされていますが、
`DomainMagicNumbers.MIN_PASSWORD_LENGTH` と整合性を保つため動的に参照してください。

<details>
<summary>修正案</summary>

```diff
  PASSWORD_TOO_WEAK = (
-     "パスワードは8文字以上で、小文字・大文字・数字・特殊文字を含む必要があります"
+     "パスワードは{min_length}文字以上で、小文字・大文字・数字・特殊文字を含む必要があります"
  )

  # 使用箇所
- raise ValidationError(UserErrors.PASSWORD_TOO_WEAK)
+ raise ValidationError(
+     UserErrors.PASSWORD_TOO_WEAK.format(
+         min_length=DomainMagicNumbers.MIN_PASSWORD_LENGTH
+     )
+ )
```
</details>
```

#### 30. コメントの品質

Check for:
- Comments that don't match the code they describe
- Unnecessary comments (code is self-explanatory)
- Missing comments where logic is non-obvious
- Comments in wrong language (project uses Japanese)

**Example comment:**
```
_🧹 Nitpick_ | _🔵 Trivial_

**【任意】コメントの内容がコードと一致していません**

コメントでは「一括取得」と記述されていますが、
実際にはループ内で1件ずつ取得しています。
コメントを実装に合わせて修正するか、実装をコメント通りに変更してください。

<details>
<summary>🔧 修正案</summary>

```diff
- # 一括取得
+ # LargeItemごとに取得（TODO: 一括取得に最適化）
  for large_item in sorted_large_items:
      sub_categories = self._repository.get_sub_categories(large_item.id)
```
</details>
```

---

## Review Process

### 1. Get Changed Files

```bash
# Get diff against base branch
git diff --name-only origin/dev...HEAD
```

### 2. 5-Pass Grouped Review

Review all changed files once per group. Each pass focuses on a specific group of concerns.

**Pass 1 — Group A: 型安全性**
For each changed file, check:
- Any型使用 (#1)
- レイヤー間の型不一致 (#2)
- FE computed/ref型注釈 (#3)
- リクエスト型アノテーション (#4)
- DI Container取得の型明示 (#5)
- Django統合時のAny回避 (#6)

**Pass 2 — Group B: アーキテクチャ・配置**
For each changed file, check:
- Feature間依存・レイヤー違反 (#7)
- FE Presentation→Infrastructure直接依存 (#8)
- Composable DIパターン準拠 (#9)
- DTO配置の一貫性 (#10)
- ファイル配置の適切性 (#11) **※Request/Result型がusecaseファイル内にないか確認**
- Result型のタプルアンパック (#12)
- トランザクション境界の配置 (#13)

**Pass 3 — Group C: エラーハンドリング・セキュリティ**
For each changed file, check:
- バリデーション・エラー処理・情報漏洩 (#14)
- APIエラー正規化 (#15)
- 初期化エラーハンドリング (#16)
- CSRF/Auth正規化 (#17)
- Serializerの機密フィールド設定 (#18)
- DB変更後のオブジェクト同期 (#19)
- ビジネスロジック計算の正確性 (#20)

**Pass 4 — Group D: パフォーマンス**
For each changed file, check:
- N+1クエリ・バッチ処理不足 (#21)
- テンプレート描画のO(N×M)探索 (#22)
- 冗長なreturn await (#23)

**Pass 5 — Group E: コード品質・DRY**
For each changed file, check:
- 未使用import・関数定義順序 (#24)
- APIヘルパーの重複 (#25)
- バリデーションロジックの重複 (#26)
- エラーメッセージ定数の一貫性 (#27)
- v-forキーの堅牢性 (#28)
- デッドコード・未使用変数 (#29)
- コメントの品質・正確性 (#30)

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

**Group A (型安全性):**
- [List type safety issues]

**Group B (アーキテクチャ):**
- [List architecture issues]

**Group C (エラーハンドリング):**
- [List error handling issues]

**Group D (パフォーマンス):**
- [List performance issues]

**Group E (コード品質):**
- [List code quality issues]

### Recommendations

1. **Must fix before merge:** [Critical/Major issues]
2. **Should fix:** [Minor issues]
3. **Optional improvements:** [Trivial issues]
```

## Red Flags - Never Do This

**General (レビュー品質):**
- Skip severity indicators on review comments
- Provide feedback without actionable suggestions (code diffs)

**Group A (型安全性):**
- Allow `Any` type usage without comment (backend and frontend)
- Approve code with missing type hints
- Ignore type inconsistency across layers (str vs int for same field)
- Miss untyped `computed()` or `ref()` in Vue components
- Allow untyped request payload objects
- Allow DI container `get()` calls without explicit type annotation
- Let Django `**kwargs: Any` pass without TypedDict+Unpack suggestion

**Group B (アーキテクチャ・配置):**
- Ignore architecture violations (feature inter-dependencies, domain layer Django imports)
- Overlook Presentation → Infrastructure direct imports
- Allow Composables to bypass DI container with direct API imports
- Miss DTO/type definitions placed in wrong architectural layer
- Ignore files placed in wrong location (should be in shared/)
- **Allow Request/Result dataclasses defined inline in usecase files (should be in types/)**
- Allow Result type indexed access (`result[0]`) instead of tuple unpacking
- Miss `transaction.atomic()` in Repository layer (must be UseCase only)

**Group C (エラーハンドリング・セキュリティ):**
- Ignore bare `fetch()`/`JSON.parse()` without try-catch in API helpers
- Allow uncaught async errors in `onMounted`/initialization code
- Skip CSRF/auth header pre-processing without try-catch
- Allow internal error information to leak to users
- Miss missing validation for edge cases in business logic calculations
- Allow password/token fields in Serializer without `write_only=True`
- Miss stale in-memory objects after DB updates (missing `refresh_from_db()`)

**Group D (パフォーマンス):**
- Miss N+1 query problems
- Ignore O(N×M) linear searches in `v-for` template rendering
- Overlook redundant `return await` in async delegation methods

**Group E (コード品質・DRY):**
- Allow duplicated boilerplate across similar API helper functions
- Allow duplicated validation logic across components
- Allow hardcoded values in error messages that should reference domain constants
- Accept display labels or array indices as `v-for` keys instead of stable IDs
- Miss dead code, unused variables, or unused type definitions
- Ignore comments that don't match the code they describe
- Give vague feedback without specific line references
- Skip providing code diffs for suggestions

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
