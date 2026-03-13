---
name: frontend-coderabbit
description: Frontend専用 CodeRabbit-style code review - Vue 3 + TypeScript + FSD + TanStack Queryの観点で5並列サブエージェントにより体系的・網羅的にレビュー。Djangoバックエンドは対象外。
---

# Frontend CodeRabbit Review（並列オーケストレーター）

Vue 3 + TypeScript + FSD (Feature-Sliced Design)のフロントエンドコードをCodeRabbitスタイルで体系的にレビューする。
**5つのサブエージェントを並列起動**し、各カテゴリを専門的にチェックする。

**Announce at start:** "I'm using the frontend-coderabbit skill to perform a comprehensive frontend code review with 5 parallel sub-agents."

**Data source:** 394 frontend inline comments from 33 PRs (recent 40 PRs analyzed)

## Format & Severity

`references/review-format.md` を参照（Language, Comment Structure, Severity, Category Labels, Summary Template）。

## Review Personality

- Formal & systematic
- 重要度を必ず明記し、actionableな修正案（diffつき）を必ず提示
- ファイルパスと行番号を参照
- `<details>` collapsibleで修正案を展開

---

## Review Process

### 1. Get Changed Files

```bash
git diff --name-only origin/dev...HEAD | grep "^frontend/"
```

変更ファイルが0件の場合は報告して終了。

### 2. 5並列サブエージェント起動

以下の5つの Agent を **同一メッセージで並列起動** する。

各サブエージェントへの共通プロンプト構造:

```
あなたはフロントエンドコードレビューのサブエージェントです。以下の手順で実行してください:

1. チェックリストを読む: Read tool で `<checklist path>` を読み込む
2. コード例示を読む: `$HOME/.claude/skills/frontend-coderabbit/references/code-examples.md`
3. プロジェクトの CLAUDE.md を読む
4. 変更ファイルを取得: `git diff --name-only origin/dev...HEAD -- 'frontend/'`
5. 各変更ファイルを Read tool で読む
6. チェックリストの全項目をチェックする（省略禁止）
7. 結果を以下のフォーマットで返す

コードの修正は行わず、検出と報告のみ行うこと。

## 出力フォーマット

| # | File | Severity | Checklist ID | Issue |
|---|------|----------|-------------|-------|
| 1 | `path/to/file:line` | 🔴/🟠/🟡/🔵 | チェック項目名 | 簡潔な説明 |

各指摘の詳細（CodeRabbitフォーマット: category + severity + title + explanation + diff）
```

#### Agent 1: FSD Architecture + Code Organization + Unused Code + Syntax

```
description: "frontend-review: fsd-architecture"
checklist: $HOME/.claude/skills/frontend-coderabbit/checklists/fsd-architecture.md
```

#### Agent 2: Type Safety + State Management

```
description: "frontend-review: type-state"
checklist: $HOME/.claude/skills/frontend-coderabbit/checklists/type-state.md
```

#### Agent 3: Error Handling + Vue.js Patterns

```
description: "frontend-review: error-vue"
checklist: $HOME/.claude/skills/frontend-coderabbit/checklists/error-vue.md
```

#### Agent 4: TanStack Vue Query + Security

```
description: "frontend-review: tanstack-security"
checklist: $HOME/.claude/skills/frontend-coderabbit/checklists/tanstack-security.md
```

#### Agent 5: Test Quality

```
description: "frontend-review: test-quality"
checklist: $HOME/.claude/skills/frontend-coderabbit/checklists/test-quality.md
```

### 3. 結果のマージ

全サブエージェントの結果を受け取り、以下を行う:

1. **重複排除** — 同一ファイル・同一行で複数エージェントが指摘した場合、より重要度の高い方を残す
2. **Severity順ソート** — 🔴 → 🟠 → 🟡 → 🔵
3. **Summary生成** — `references/review-format.md` の Review Summary Template に従う

### 4. Generate Summary

```markdown
## Review Summary

**Actionable comments posted: <N>**

### Sub-Agent Results

| Agent | Category | Findings |
|-------|----------|----------|
| 1 | FSD Architecture + Code Org | <N>件 |
| 2 | Type Safety + State Mgmt | <N>件 |
| 3 | Error Handling + Vue Patterns | <N>件 |
| 4 | TanStack Query + Security | <N>件 |
| 5 | Test Quality | <N>件 |

### Severity Distribution

- 🔴 Critical: <N>
- 🟠 Major: <N>
- 🟡 Minor: <N>
- 🔵 Trivial: <N>
```

---

## Red Flags - Never Do This

- 重要度インジケーターを省略
- actionableな修正案なしにフィードバック
- チェックリストの項目をスキップ
- FSD index.ts直接importを見逃す
- features間の直接importを見逃す
- `any`/`enum`/`console.*`/`as`/`!`の使用を見逃す
- composable stateのreadonly保護漏れを見逃す
- `v-for`のindex keyを見逃す
- Floating Promiseを見逃す
- コードdiffなしに修正案を提示
- **サブエージェントを直列で実行する（必ず並列起動）**

---

## Sub-Agent Output Format

サブエージェントとして実行された場合も、内部で5並列サブエージェントを起動し、結果をマージして以下の構造で返す。

### 出力構造

```markdown
## Findings

| # | File | Severity | Checklist ID | Issue | Status |
|---|------|----------|-------------|-------|--------|
| 1 | `path/to/file:line` | 🔴/🟠/🟡/🔵 | Core/Ext ID | 簡潔な説明 | 修正済み/要対応 |

### Details

（各Findingの詳細: CodeRabbitフォーマットで修正案diff付き）

## Out of Scope（スコープ外と判断したもの）

| # | Item | Reason |
|---|------|--------|
| 1 | 説明 | スコープ外の理由 |

## Summary

- **Total findings:** N
- **修正済み:** N（サブエージェントが自動修正したもの）
- **要対応:** N（人間の判断が必要なもの）
- **スコープ外:** N
- **Severity分布:** 🔴 N / 🟠 N / 🟡 N / 🔵 N
```

### ルール

- FindingsはSeverity順（🔴 → 🟠 → 🟡 → 🔵）
- Checklist IDはCore/Extended Checklistの項目名と対応させる
- 「修正済み」は実際にコードを変更した場合のみ
- スコープ外の理由は具体的に（例: 「既存コードの問題で今回の変更範囲外」「別Feature/PRの責任範囲」「広範なリファクタが必要で個別修正は不適切」）
- Detailsは通常のCodeRabbitフォーマット（category + severity + title + explanation + diff）を使用
