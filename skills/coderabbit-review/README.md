# CodeRabbit Review Skill

This skill mimics CodeRabbit AI's formal, systematic code review style based on 354 real review comments collected from the forval-crossgear repository.

## Characteristics

**Personality:**
- Formal and professional
- Systematic and methodical
- Comprehensive and thorough
- Japanese-language capable
- Always provides actionable suggestions

**Review Style:**
- Severity indicators: 🔴 Critical, 🟠 Major, 🟡 Minor, 🔵 Trivial
- Category labels: _⚠️ Potential issue_, _🧹 Nitpick_, _🛠️ Refactor suggestion_
- Structured formatting with collapsible `<details>` sections
- Code diffs showing before/after
- AI agent prompts for automated fixes
- Line numbers and file path references

## Usage

```bash
# In Claude Code
User: Review this PR using coderabbit style
Assistant: [Invokes coderabbit-review skill]
```

Or use the Skill tool:
```
/coderabbit-review
```

## Focus Areas

1. **Architecture Compliance** - Feature dependencies, Domain layer purity, Transaction management
2. **Type Safety** - Missing type hints, Any type usage, Enum requirements
3. **Database Performance** - N+1 queries, select_related/prefetch_related
4. **Validation & Error Handling** - Input validation, Custom exceptions, Error messages
5. **Code Organization** - DRY violations, Unused imports, Function order

## Example Output

```markdown
_⚠️ Potential issue_ | _🟠 Major_

**【要改善】yearの範囲(1900〜9999)の検証が不足しています**

yearが0以下のみチェックされ、1899や10000が通過します。ドメイン/DBの
「1900〜9999」前提と不整合になり得るため、範囲チェックを追加してください。

<details>
<summary>修正案</summary>

```diff
  if year <= 0:
      return failure(ValueError(ValidationErrors.YEAR_FORMAT_INVALID))
+ if year < 1900 or year > 9999:
+     return failure(ValueError(ValidationErrors.YEAR_OUT_OF_RANGE))
```
</details>
```

## Data Source

Based on 354 CodeRabbit review comments from PRs:
- #333 (79 comments) - Database/ORM features
- #331 (70 comments) - Suspension feature
- #340 (48 comments) - Feature enhancement
- #343 (44 comments) - Core functionality
- And 10 more PRs

Comments collected on: 2026-01-30

## References

- `/tmp/coderabbit_comments.txt` - Full comment database (222 KB)
- `/tmp/COLLECTION_REPORT.md` - Detailed analysis report
- `/tmp/coderabbit_samples.txt` - Representative examples
