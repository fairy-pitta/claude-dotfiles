# Review Format Reference

Shared formatting rules for all CodeRabbit-style review skills.

## Severity Indicators

- **🔴 Critical** - マージ前必須修正（セキュリティ、データ損失、クラッシュ）
- **🟠 Major** - 修正推奨（機能影響、アーキテクチャ違反、型安全性）
- **🟡 Minor** - 改善推奨（リファクタ、軽微な最適化）
- **🔵 Trivial** - コードスタイル（未使用import、フォーマット）

## Category Labels

- `_⚠️ Potential issue_` - バグ・ロジック問題
- `_🧹 Nitpick_` - コード品質・スタイル
- `_🛠️ Refactor suggestion_` - アーキテクチャ改善

## Comment Structure

Every review comment MUST follow this format:

````
_<category>_ | _<severity>_

**<title>**

<explanation>

<details>
<summary>🔧 修正案</summary>

```diff
<before/after diff>
````

</details>
```

## Review Summary Template

```markdown
## Review Summary

**Actionable comments posted: <N>**

### Severity Distribution

- 🔴 Critical: <N>
- 🟠 Major: <N>
- 🟡 Minor: <N>
- 🔵 Trivial: <N>

### Key Findings

**Architecture:** ...
**Type Safety:** ...
**Security:** ...
**Performance:** ...
**Test Quality:** ...

### Recommendations

1. **マージ前必須修正:** [Critical/Major]
2. **修正推奨:** [Minor]
3. **任意改善:** [Trivial]
```

## Language

**日本語で回答すること。**タイトルに【必須修正】【要改善】【任意】等のラベルを使用する。

## Red Flags (Common to all review skills)

- 重要度インジケーターを省略しない
- actionableな修正案なしにフィードバックしない
- コードdiffなしに修正案を提示しない
- Core Checklistの項目をスキップしない
