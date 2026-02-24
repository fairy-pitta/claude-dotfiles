# Commit and Push Changes

Commit and push the current changes with strategic git practices.

Context: $ARGUMENTS

## Strategy Selection

### Strategy B: New Commit（デフォルト）
独立した新しいコミットを作成する。**これがデフォルト。**
```bash
git add <files>
git commit -m "type: 説明"
git push
```

### Strategy A: Squash/Amend
直前のコミットへの軽微な追記（誤字修正・コメント追加等、内容が完全に同一テーマ）のみ使用。**明示的に指示された場合のみ。**
```bash
git add <files>
git commit --amend --no-edit
git push --force-with-lease
```

### Strategy C: Interactive Rebase
複数コミットを整理したい場合。**明示的に指示された場合のみ。**
```bash
git rebase -i origin/dev
git push --force-with-lease
```

## Commit Message Rules（最重要）

このリポジトリは **squash & merge** 運用のため、コミットメッセージがそのままPRの変更履歴として残る。
**コミットメッセージだけ読めば何をしたか即座にわかるように書くこと。**

### フォーマット

```
type: 何をしたかの具体的な説明（日本語、50字以内を目安）

[任意: なぜその変更が必要かの補足]
```

**type一覧:** `feat` / `fix` / `refactor` / `test` / `docs` / `chore` / `style` / `perf`

### 禁止表現（絶対に使わない）

以下のような**何をしたかが伝わらない抽象的なメッセージは禁止**:

| ❌ 禁止 | 理由 |
|---|---|
| `fix: PRレビュー指摘を反映` | 何を直したか不明 |
| `fix: レビュー対応` | 同上 |
| `chore: 修正` | 何の修正か不明 |
| `fix: コメント対応` | 同上 |
| `feat: 実装` | 何を実装したか不明 |
| `fix: 諸々修正` | 複数変更を丸めている |

### 良い例

```
fix: UserRepositoryがPresentation DTO(AuthUserPayload)を返す依存方向を是正
feat: 推移表AIアドバイスに月カラム選択UIを追加
fix: v-forのkeyをindex→posting_idに変更してDOM再利用の不整合を防止
refactor: テスト命名をtest_<動作>_<条件>_<期待結果>の順序に統一
fix: AccountTitleSerializerにthree_month_averageフィールドが存在しないAttributeErrorを修正
```

### 変更が複数テーマにまたがる場合は複数コミットに分ける

1つのコミットメッセージで表現しきれない変更は、**テーマごとに分けて複数コミットにする。**

```bash
# ❌ Bad: 1コミットに詰め込む
git add -A
git commit -m "fix: 諸々修正"

# ✅ Good: テーマ別に分割
git add backend/app/features/user/
git commit -m "fix: UserRepositoryのDTO依存方向を是正"

git add frontend/src/features/auth/
git commit -m "fix: ChangePasswordModal.vueのFloating Promiseをvoid修飾に修正"
```

## Critical Rules

- **main/master ブランチへ直接コミットは絶対NG**
- `git add -A` は使わず、変更ファイルを個別に確認して `git add <file>` でステージング
- コミット前に `git diff --staged` で差分を確認
- コミットメッセージは**日本語**（CLAUDE.mdルール準拠）

## Process

1. 現在のブランチを確認（デフォルトブランチでないことを検証）
2. `git diff --staged` および `git status` で変更内容とテーマを把握
3. テーマが複数あれば分割コミットを計画する
4. 各テーマについて具体的なコミットメッセージを作成（禁止表現チェック）
5. `git add <files>` → `git commit -m "..."` → `git push`
6. コミットハッシュを報告
