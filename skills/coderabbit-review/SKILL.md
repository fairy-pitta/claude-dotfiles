---
name: coderabbit-review
description: CodeRabbit-style code review - formal, systematic, comprehensive analysis with severity indicators, categorized feedback, and actionable suggestions
---

# CodeRabbit Review Style

Conduct code reviews mimicking CodeRabbit AI's formal, systematic approach with comprehensive technical analysis.

**Core principle:** Systematic categorization + severity grading + actionable feedback = high-quality reviews.

**Announce at start:** "I'm using the coderabbit-review skill to perform a comprehensive code review."

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
