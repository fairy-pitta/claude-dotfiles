---
name: test
description: Run project tests, analyze failures, and auto-fix until all pass. Detects backend (pytest) and frontend (vitest) automatically.
---

# Test Runner

プロジェクトのテストを実行し、失敗があれば自動修正する。

**Announce at start:** "テストを実行します"

## Step 1: Detect Project Type

変更ファイルまたはカレントディレクトリから対象を判定する。

```bash
git diff --name-only origin/dev...HEAD
```

- `backend/` に変更あり → `HAS_BACKEND=true`
- `frontend/` に変更あり → `HAS_FRONTEND=true`
- 判定できない場合は両方実行する

`$ARGUMENTS` で明示指定がある場合はそちらを優先:
- `--backend` / `--be` → backend のみ
- `--frontend` / `--fe` → frontend のみ
- `--all` → 両方
- 特定のテストファイルパスやパターン → そのまま渡す

## Step 2: Run Tests

### Backend (pytest)

```bash
cd backend && python -m pytest $TEST_ARGS -x --tb=short 2>&1
```

`$TEST_ARGS`: ユーザーが特定ファイル/パターンを指定した場合はそれを使用。未指定なら引数なし（全テスト）。

### Frontend (vitest)

```bash
pnpm -C frontend run test:unit $TEST_ARGS 2>&1
```

加えて型チェック・lint も実行:

```bash
pnpm -C frontend run type-check 2>&1
pnpm -C frontend run lint 2>&1
```

## Step 3: Analyze Failures

テストが全てパスした場合 → Step 5 へ。

失敗がある場合:
1. エラーメッセージとスタックトレースを分析
2. 失敗原因を分類:
   - **コードバグ**: 実装コードの問題 → 修正
   - **テストバグ**: テスト側の期待値やセットアップの問題 → 修正
   - **環境問題**: DB接続、ポート競合、依存不足 → ユーザーに報告して中断
3. 修正方針を決定

## Step 4: Auto-Fix (max 3 rounds)

```
[Round N] 失敗: <N>件
修正: <file:line> - <what changed>
```

1. Read tool で失敗箇所のコードを読む
2. Edit tool で修正
3. テスト再実行
4. まだ失敗 → Round N+1（最大3ラウンド）
5. 3ラウンド後も失敗 → 残りの失敗をレポートして終了

## Step 5: Report

```
=== Test Result ===
Backend:  PASS (42 passed) / SKIP / FAIL (3 failed)
Frontend: PASS (108 passed) / SKIP / FAIL (5 failed)
Type-check: PASS / FAIL
Lint: PASS / FAIL

Auto-fixed: <N>件
- <file>:<line> - <description>
```

## Red Flags

- **環境問題を自動修正しない** — DB接続エラー等はユーザーに報告
- **テストをスキップ/削除して通す修正はしない**
- **関係ないコードを変更しない**
- **3ラウンド超えて修正ループを続けない**
