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

Review categories derived from CLAUDE.md rules + analysis of 277 CodeRabbit and 21 human reviewer comments from 20 recent PRs. Frequency annotations (e.g. `[5+ PR]`) indicate how often the issue was flagged.

### 1. Architecture Compliance

Check against CLAUDE.md rules:
- **Feature inter-dependencies** `[5+ PR]` - 通常Feature間の直接import（例: journal→accounting）がないか。`shared/types/`経由ルールに違反していないか。許可: 全Feature→shared/, 全Feature→user/organization, summaries→他Feature(読取専用)
- **Domain layer purity** `[2 PR]` - Domain層（entities, repositories, enums）がDjango/DRFに依存していないか。ページングデフォルト値などインフラ概念がDomainに混入していないか
- **Presentation→Infrastructure direct dependency** `[2 PR]` - UIコンポーネントやComposableがRepositoryImplやAPI関数を直接参照していないか。UseCase/Interface経由のアクセスになっているか
- **Transaction management placement** `[3 PR]` - `transaction.atomic()`がUseCase層でのみ管理されているか。エラー時にrollbackが正しく発火するか
- **1 class = 1 file** - 各クラスが独自のファイルに配置されているか

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

### 2. Type Safety & Layer Consistency

Check for:
- **Missing type hints** - `Protocol`/`TypedDict`/`Generic` required。`Any`型は禁止
- **Result type tuple unpacking** `[3+ PR]` - `result, error = usecase.execute(request)`の形式か。`.error`属性アクセスや、errorチェック省略による認可バイパスがないか
- **Enum usage for status/category** `[2 PR]` - ステータス値・カテゴリ値に文字列リテラルを使用していないか。`TextChoices`/`IntegerChoices`を使っているか
- **Serializer/Domain model field mismatch** `[2 PR]` - APIレスポンスのフィールド名がDomainエンティティやUseCaseResultと整合しているか。存在しないフィールドがSerializerに定義されていないか
- **Unnecessary broad types** - `str | int`のように不要に広い型を受け入れていないか。`company_id`は常に`int`か

**Example comment:**
```
_⚠️ Potential issue_ | _🔴 Critical_

**【必須修正】シリアライザーとドメインモデルのフィールド名が不整合です**

`FinancialMetricsSerializer`に定義された`three_month_average`フィールドが、
対応するドメインモデル`RevenuePerEmployeeValue`に存在しません。
シリアライズ時にAttributeErrorが発生します。

<details>
<summary>🔧 修正案</summary>

```diff
# Option A: ドメインモデルにフィールドを追加
@dataclass(frozen=True)
class RevenuePerEmployeeValue:
    monthly: Decimal
+   three_month_average: Decimal

# Option B: シリアライザーから不要なフィールドを削除
- three_month_average = serializers.DecimalField(...)
```
</details>
```

### 3. Security & Authorization

Check for:
- **permission_classes explicit setting** `[2 PR]` - DRF Viewに`permission_classes`が明示的に設定されているか。デフォルトに依存してセキュリティホールが生まれていないか
- **Authorization bypass prevention** `[2 PR]` - Result型の誤用やエラーハンドリングの不備により、認可チェックがスキップされる経路がないか
- **write_only on sensitive fields** `[1 PR]` - パスワード等の機密フィールドに`write_only=True`が設定されているか。レスポンスに機密データが漏れていないか
- **Token invalidation** - パスワード変更・ログアウト時にトークンが適切に無効化されているか

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】`permission_classes` を明示的に設定してください**

このViewには`permission_classes`が指定されていません。
DRFのデフォルト設定に依存すると、設定変更時に意図しないアクセス許可が発生するリスクがあります。

<details>
<summary>🔧 修正案</summary>

```diff
  class EmailVerificationView(APIView):
+     permission_classes = [AllowAny]
```
</details>
```

### 4. Error Messages & Constants

Check for:
- **Error message constants** `[6+ PR]` - 文字列リテラルでエラーメッセージを直接記述していないか。`app/shared/constants/`等の定数ファイルで管理しているか
- **logger/print prohibition** `[1 PR]` - `logger`や`print`（マイグレーションのbackward含む）を使用していないか。例外伝播やResult型で処理しているか

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】エラーメッセージを定数化してください**

`"有効な会社IDが必要です。"`が2箇所で文字列リテラルとして使用されています。
`app/shared/constants/`に定数として定義し、一元管理してください。

<details>
<summary>🔧 修正案</summary>

```diff
+ # app/shared/constants/error_messages.py
+ COMPANY_ID_REQUIRED = "有効な会社IDが必要です。"

- raise ValueError("有効な会社IDが必要です。")
+ raise ValueError(ErrorMessages.COMPANY_ID_REQUIRED)
```
</details>
```

### 5. Database Performance

Check for:
- **N+1 query problems** `[3 PR]` - ループ内でDBクエリを実行していないか。`select_related()`/`prefetch_related()`の適用漏れがないか
- **Bulk operations** - 複数レコードの作成・更新時に`bulk_create()`/`bulk_update()`を使用しているか
- **Unnecessary query executions** - 不要なクエリ発行がないか

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

### 6. Validation & Error Handling

Check for:
- **Input validation completeness** `[2 PR]` - 必要なバリデーション（重複チェック、既使用チェック、必須項目チェック等）が漏れていないか
- **Edge case consideration** `[1 PR]` - 同時リクエスト・タイミング問題・境界値（`<=` vs `<`）などのエッジケースが考慮されているか
- **Validation execution order** - 削除・更新処理の前にバリデーションが実行されているか。先に副作用を起こしてからチェックしていないか
- **Data access correctness** `[1 PR]` - リレーション先のフィールドに正しくアクセスできるか。NULLの可能性があるフィールドへの安全なアクセスがされているか
- **Post-normalization validation** `[1 PR]` - 入力値を正規化・変換した後に、結果が有効か再検証しているか。例: `normalize_month_params()`後に空配列になるケースをエラーとして弾いているか

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

### 7. Test Quality

Check for:
- **pytest function-based style** `[4 PR]` - `class TestXxx`ではなく`def test_xxx()`の関数ベースpytestスタイルで記述されているか。命名規約（`test_<対象>_<条件>_<期待結果>`）、`Mock(spec=...)`の使用
- **Normal case test coverage** `[2 PR]` - 異常系テストのみで正常系が抜けていないか。主要ユースケースのテストカバレッジが確保されているか
- **Test data independence** `[1 PR]` - テスト間で共有される可変な辞書・リスト（ミュータブルデフォルト引数等）がないか。テスト汚染を防げているか
- **Edge case testing** - 同時リクエスト・境界値などのエッジケースがテストされているか

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】pytestの関数ベース＋命名規約に合わせてください。**

プロジェクトのテスト方針として、クラスベース（`class TestXxx`）ではなく
関数ベース（`def test_xxx()`）のpytestスタイルを採用しています。
`spec=True`（`autospec=True`）でモックの型安全性も確保してください。

<details>
<summary>🔧 修正案</summary>

```diff
- class TestChangePasswordUseCase:
-     def test_success(self):
-         mock_repo = Mock()
+ def test_change_password_success():
+     mock_repo = Mock(spec=UserRepository)
```
</details>
```

### 8. Unused Code Detection

Check for:
- Unused functions/methods (defined but never called)
- Unused interfaces/types/constants
- Unused imports
- Helper functions only used by other unused functions (cascading dead code)
- Orphaned type definitions, error messages, API constants left after deletions

**Example comment:**
```
_🧹 Nitpick_ | _🟡 Minor_

**【要改善】未使用の関数`generateMonthKey`を削除してください**

`generateMonthKey`はコードベース内のどこからも呼び出されていません。
また、この関数内でのみ使用されている`isValidAccountingMonth`も連鎖的に
未使用となるため、合わせて削除してください。

<details>
<summary>🔧 修正案</summary>

```diff
- static generateMonthKey(fiscalYear: number, month: number): string {
-   if (!this.isValidAccountingMonth(month)) {
-     throw new RangeError(ERROR_MESSAGES.VALIDATION.MONTH_OUT_OF_RANGE(month))
-   }
-   const monthStr = month < 10 ? `0${month}` : `${month}`
-   return `${fiscalYear}-${monthStr}`
- }
-
- static isValidAccountingMonth(month: number): boolean {
-   return (
-     month >= ACCOUNTING_MONTH_CONFIG.VALID_RANGE.min &&
-     month <= ACCOUNTING_MONTH_CONFIG.VALID_RANGE.max
-   )
- }
```
</details>
```

### 9. Code Organization & DRY

Check for:
- **DRY principle violations** `[2 PR]` - 同一・類似のヘルパーメソッドやバリデーションロジックが複数箇所に存在していないか
- **Code intent clarity** `[2 PR]` - 変数名・メソッド名・コメントからコードの意図が読み取れるか
- **Deprecated API usage** `[1 PR]` - 非推奨（deprecated）のDjango API（例: `CheckConstraint`のclass引数）を使用していないか。新しい推奨APIに置き換えられているか
- **Comment accuracy** `[1 PR]` - コメントが実際のコードの挙動と一致しているか。例: 「13を含む」と書かれているが実際は「decision1」を含む等、誤解を招くコメントがないか
- **Type annotation style consistency** `[1 PR]` - 同一ファイル内で`Union[A, B]`と`A | B`が混在していないか。PEP 604対応済みプロジェクトでは`|`構文に統一する
- **Import organization** - 未使用import、import順序
- **Function definition order** - 適切な定義順序

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
```

### 10. Migration & DB Schema

Check for:
- **Reverse migration implementation** `[1 PR]` - `reverse_code`がnoopではなく、ロールバック可能な実装か
- **Rollback risk assessment** `[1 PR]` - データ破壊的なマイグレーション（カラム削除、型変更等）にデータ保全策があるか。ロールバックで既存データまで消える可能性がないか
- **Bulk operations in migrations** - 大量データの更新時に`bulk_update()`やiteratorの`chunk_size`指定を使用しているか

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】リバースマイグレーションが `noop` になっています**

`reverse_code`が空の`RunPython.noop`では、マイグレーションをロールバックできません。
データの復元ロジックを実装するか、明示的に`migrations.RunPython.noop`の理由をコメントしてください。
```

### 11. Frontend Quality (Vue.js / TypeScript)

Check for:
- **v-for :key stability** `[1 PR]` - `v-for`の`:key`にarray indexを使用していないか。行の追加・削除時にDOM再利用の不整合が発生する。`posting_id`等の安定した識別子をキーに使うこと
- **Async race conditions** `[1 PR]` - Composable内の非同期関数が連続呼び出しされた場合、古いレスポンスが最新の状態を上書きしないか。requestIdガードパターンで最新リクエストのみ反映するようにする
- **Floating Promises** `[1 PR]` - `async`関数を`await`も`void`もなしに呼び出していないか。意図的なfire-and-forgetなら`void`を明示する（`void fetchData()`）
- **Business logic guard consistency** `[1 PR]` - UIレベルのガード（例: `isClickable` computed）だけでなく、イベントハンドラ等のビジネスロジック層でも同じ制約を担保しているか。UIガードだけではエッジケースで迂回される可能性がある
- **Implicit truthiness vs explicit checks** - `if (value)` による暗黙のtruthyチェックで `null`・`undefined`・空文字が意図通りに処理されるか。型に応じて `value != null && value !== ''` 等の明示的チェックを推奨

**Example comment:**
```
_⚠️ Potential issue_ | _🟠 Major_

**【必須修正】連続フェッチ時に古いレスポンスで状態が上書きされる競合状態**

複数の`fetchDetails`呼び出しが重なった場合、先の呼び出しの古いレスポンスが
後から返ると表示データがズレます。requestIdガードで最新のみ反映してください。

<details>
<summary>🔧 修正案</summary>

```diff
+ const latestRequestId = ref(0)

  async function fetchDetails(params) {
+   const requestId = ++latestRequestId.value
    isLoading.value = true
    try {
      const response = await repository.getData(params)
+     if (requestId !== latestRequestId.value) return
      data.value = response.data
    } catch (e) {
+     if (requestId !== latestRequestId.value) return
      error.value = e
    } finally {
-     isLoading.value = false
+     if (requestId === latestRequestId.value) {
+       isLoading.value = false
+     }
    }
  }
```
</details>
```

### 12. Syntax & Basic Quality

Check for:
- **Syntax errors** `[3 PR]` - importの括弧閉じ忘れ、重複パラメータ定義、未解決のマージコンフリクトマーカー（`<<<<<<<`）がないか
- **Naming convention compliance** - ファイル名・クラス名がCLAUDE.mdの命名規約（1クラス=1ファイル、UseCase/Request/Result/Response/Payloadの命名パターン）に従っているか

## Review Process

### 1. Get Changed Files

```bash
# Get diff against base branch
git diff --name-only origin/dev...HEAD
```

### 2. Analyze Each File

For each changed file, check all 12 review focus areas:
1. Architecture Compliance (Feature dependencies, Domain purity, layer violations)
2. Type Safety & Layer Consistency (Any, Result type, Serializer/Domain mismatch)
3. Security & Authorization (permission_classes, write_only, auth bypass)
4. Error Messages & Constants (string literals, logger/print)
5. Database Performance (N+1, bulk operations)
6. Validation & Error Handling (completeness, edge cases, order, post-normalization)
7. Test Quality (pytest style, normal case coverage, test data independence)
8. Unused Code Detection (functions, types, imports, constants)
9. Code Organization & DRY (duplication, deprecated APIs, intent clarity, comment accuracy)
10. Migration & DB Schema (reverse migration, rollback risks)
11. Frontend Quality (v-for key, async race conditions, floating promises, guard consistency)
12. Syntax & Basic Quality (syntax errors, merge conflicts, naming)

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

**Type Safety & Layer Consistency:**
- [List type/mismatch issues]

**Security:**
- [List security issues]

**Error Messages & Constants:**
- [List constant issues]

**Performance:**
- [List performance issues]

**Validation:**
- [List validation issues]

**Test Quality:**
- [List test issues]

**Code Quality:**
- [List code quality issues]

**Migration:**
- [List migration issues]

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
- Miss unused functions/methods/types (dead code)
- Skip providing code diffs for suggestions
- Give vague feedback without specific line references

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
