---
name: review-loop
description: Repeat backend-coderabbit or frontend-coderabbit reviews (5 parallel sub-agents each) until all findings on the current branch are addressed.
---

# Review Loop

backend-coderabbit / frontend-coderabbit スキルを繰り返し実行し、指摘箇所を全て解消するまでループするスキル。
各レビューは **5並列サブエージェント** で実行される。

## Process

### 0. レビュースキルの決定

```bash
git diff --name-only origin/dev...HEAD
```

| 変更ファイル     | 使用するスキル                   |
| ---------------- | -------------------------------- |
| `backend/` のみ  | backend-coderabbit (5並列)       |
| `frontend/` のみ | frontend-coderabbit (5並列)      |
| 両方             | 両スキル (最大10並列)            |

### 1. 初回レビュー実行

上記で決定したスキルの **カテゴリ別チェックリストを直接サブエージェントで並列起動** する。

**Backend (5並列):**

| Agent | checklist |
|-------|-----------|
| `backend-review: architecture` | `$HOME/.claude/skills/backend-coderabbit/checklists/architecture.md` |
| `backend-review: type-safety` | `$HOME/.claude/skills/backend-coderabbit/checklists/type-safety.md` |
| `backend-review: db-performance` | `$HOME/.claude/skills/backend-coderabbit/checklists/db-performance.md` |
| `backend-review: test-quality` | `$HOME/.claude/skills/backend-coderabbit/checklists/test-quality.md` |
| `backend-review: security-errors` | `$HOME/.claude/skills/backend-coderabbit/checklists/security-errors.md` |

**Frontend (5並列):**

| Agent | checklist |
|-------|-----------|
| `frontend-review: fsd-architecture` | `$HOME/.claude/skills/frontend-coderabbit/checklists/fsd-architecture.md` |
| `frontend-review: type-state` | `$HOME/.claude/skills/frontend-coderabbit/checklists/type-state.md` |
| `frontend-review: error-vue` | `$HOME/.claude/skills/frontend-coderabbit/checklists/error-vue.md` |
| `frontend-review: tanstack-security` | `$HOME/.claude/skills/frontend-coderabbit/checklists/tanstack-security.md` |
| `frontend-review: test-quality` | `$HOME/.claude/skills/frontend-coderabbit/checklists/test-quality.md` |

各サブエージェントの共通プロンプト:
```
あなたはコードレビューのサブエージェントです。

1. チェックリストを読む: `<checklist_path>`
2. コード例示を読む: `<skill_dir>/references/code-examples.md`
3. 共通フォーマットを読む: `$HOME/.claude/skills/references/review-format.md`
4. プロジェクトの CLAUDE.md を読む
5. `git diff --name-only origin/dev...HEAD -- '<path_filter>'` で変更ファイルを取得
6. 各変更ファイルを読んでレビューを実施（全項目必須）
7. 結果をテーブル + 詳細フォーマットで返す

コードの修正は行わず、検出と報告のみ行うこと。
```

レビュー結果を確認し、指摘事項を収集する。

### 2. 指摘事項の分析

全サブエージェントのレビュー結果を集約・重複排除し、以下を抽出：

- 🔴 Critical（必須修正）
- 🟠 Major（要修正）
- 🟡 Minor（改善推奨）
- 🔵 Trivial（任意）

指摘がない場合は**完了**として終了。

### 3. 指摘事項の修正

優先度順（Critical → Major → Minor → Trivial）に修正を実施：

1. 各指摘の修正案（diff）を参照
2. コードを修正
3. 修正内容を簡潔に記録

**修正時の注意:**

- Critical/Majorは必ず修正
- Minor/Trivialは可能な限り修正（明らかに不要な場合はスキップ可）
- 修正案がある場合はそれに従う
- 修正案がない場合は指摘内容に基づき適切に対応
- 修正が終わったら、リンターやテストを全て実行し、デグレをしていないことを都度確かめること。

### 4. 再レビュー

修正完了後、再度同じカテゴリ別サブエージェントを並列起動する。

### 5. ループ判定

- 指摘が**0件**の場合 → **完了**
- 指摘が残っている場合 → ステップ3に戻る

### 6. 最大ループ回数

無限ループ防止のため、**最大20回**のループで終了。
20回を超えても指摘が残る場合は、残りの指摘事項を報告して終了。

## Output Format

### 各ループの報告

```markdown
## Loop <N> Results

**レビュー指摘数（カテゴリ別）:**

| Category | 🔴 | 🟠 | 🟡 | 🔵 | 計 |
|----------|-----|-----|-----|-----|-----|
| architecture | <N> | <N> | <N> | <N> | <N> |
| type-safety | <N> | <N> | <N> | <N> | <N> |
| ... | ... | ... | ... | ... | ... |

**修正した項目:**

1. <ファイル名>: <修正内容>
2. ...

**次のアクション:** 再レビュー実行 / 完了
```

### 完了時の報告

```markdown
## Review Loop Complete

**総ループ回数:** <N>
**修正した指摘総数:** <N>

**修正サマリー:**

- <カテゴリ>: <N>件修正
- ...

全ての指摘事項が解消されました。
```

## Critical Constraints

- **毎回必ずカテゴリ別チェックリストのサブエージェントを並列起動すること**（直接レビューを行わない）
- 修正はスキルの指摘に基づくこと
- 新しい問題を導入しないよう注意
- 最大20回のループで終了
- 各ループの結果を明確に報告

## Usage

```
/review-loop
```

引数なしで実行。現在のブランチの変更ファイルをレビュー対象とする。
