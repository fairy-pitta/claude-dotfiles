---
name: resolve-issues
description: GitHub Issueから独立・解決可能なものを選別し、それぞれworktreeで並列にエージェントが調査→実装→テスト→PR作成まで行う。
---

# Resolve Issues

GitHub リポジトリの未解決 Issue を分析し、独立して解決可能なものを選別。各 Issue をそれぞれ別の worktree で並列にエージェントが実装し、テスト通過後に PR を作成する。

引数: $ARGUMENTS

- 引数なし → open Issue を取得して自動選別
- Issue 番号/URL を複数指定 → 指定された Issue のみ対象（例: `#12 #15 #20`）
- `--limit N` → 同時処理数の上限（デフォルト: 3）
- `--label <label>` → 指定ラベルの Issue のみ対象
- `--dry-run` → 選別結果の表示のみ（実装しない）

**開始時アナウンス:** "resolve-issues を開始します。Issue選別 → ユーザー承認 → 並列worktree実装 → PR作成 の流れで進めます。"

---

## Phase 1: Issue の取得と分析

### 1-1. Issue 一覧の取得

```bash
# ラベル指定がある場合
gh issue list --state open --label "<label>" --limit 30 --json number,title,body,labels,assignees,comments

# 指定なしの場合
gh issue list --state open --limit 30 --json number,title,body,labels,assignees,comments
```

$ARGUMENTS に Issue 番号/URL が直接指定されている場合はそれらのみ取得:

```bash
gh issue view <number> --json number,title,body,labels,assignees,comments
```

### 1-2. Issue のフィルタリング（自動除外）

以下の Issue は自動的に除外する:

- **既にアサイン済み**: `assignees` が空でない
- **Draft/WIP**: タイトルに `[WIP]`, `[Draft]`, `draft:` を含む
- **議論中**: ラベルに `discussion`, `question`, `needs-triage` を含む
- **ブロック中**: ラベルに `blocked`, `waiting` を含む

### 1-3. 解決可能性と独立性の分析

Agent tool で Explore エージェントを起動し、各 Issue を分析する:

```
subagent_type: "Explore"
description: "analyze issues for resolution"
prompt: |
  以下の GitHub Issue リストを分析し、各 Issue について評価してください。

  ## Issue リスト
  <フィルタリング後の Issue 一覧>

  ## 評価基準

  ### 解決可能性（Solvability）
  各 Issue について以下を調査:
  1. Issue で言及されているファイル・クラス・関数がコードベースに存在するか
  2. 問題の再現条件や期待動作が明確か
  3. 修正範囲が推定可能か（ファイル数の目安）
  4. 外部依存（DB マイグレーション、環境変数追加等）が不要か

  スコア: HIGH（明確で修正範囲小）/ MEDIUM（概ね明確だが調査必要）/ LOW（曖昧または大規模）

  ### 独立性（Independence）
  Issue 間で以下が重複しないかチェック:
  1. 同じファイルを変更する Issue 同士はコンフリクトリスクあり
  2. 同じ機能領域（Feature）に属する Issue 同士は注意
  3. 前提関係がある Issue（A を解決しないと B が解決できない）

  ### 出力形式（JSON）
  {
    "issues": [
      {
        "number": 123,
        "title": "...",
        "solvability": "HIGH|MEDIUM|LOW",
        "solvability_reason": "...",
        "estimated_files": ["path/to/file1.py", "path/to/file2.py"],
        "feature_area": "accounting|journal|...",
        "has_external_deps": false,
        "conflicts_with": [456],  // 他の Issue 番号
        "recommended": true|false
      }
    ],
    "independent_groups": [
      [123, 789],  // 同時に着手可能なグループ
      [456]        // 別グループ（123と競合するため）
    ]
  }
```

---

## Phase 2: ユーザー承認

### 2-1. 選別結果の提示

分析結果をもとに、推奨 Issue を提示する:

```
=== Issue 選別結果 ===

## 推奨（同時着手可能）
| #   | タイトル                         | 解決可能性 | 推定変更ファイル数 | Feature |
|-----|----------------------------------|-----------|-------------------|---------|
| #12 | XXXのバリデーションエラー          | HIGH      | 2                 | accounting |
| #15 | YYYの一覧が空になる               | HIGH      | 3                 | journal    |
| #20 | ZZZのテストが不安定               | MEDIUM    | 1                 | shared     |

## 除外
| #   | タイトル        | 理由                           |
|-----|----------------|-------------------------------|
| #18 | AAA の改善      | #12 と同じファイルを変更（競合リスク） |
| #25 | BBB の追加      | 解決可能性 LOW（要件が曖昧）      |

## 処理上限: 3件（--limit で変更可能）

この Issue を並列で解決に着手しますか？
- 番号を指定して除外/追加も可能です（例: "#20 を除外", "#18 も追加"）
- "OK" / "LGTM" で着手開始
```

`--dry-run` 指定時はここでスキル終了。

### 2-2. ユーザー判断

- **OK / LGTM**: Phase 3 へ
- **修正指示**: リストを調整して再提示
- **却下**: スキル終了

---

## Phase 3: 並列 Worktree 実装

### 3-1. 各 Issue に対してエージェントを並列起動

**承認された各 Issue に対して、Agent tool を `isolation: "worktree"` で並列起動する。**

全エージェントを **1つのメッセージ内で同時に** 起動すること（逐次起動は禁止）。

各エージェントのプロンプト:

```
description: "resolve issue #<number>"
isolation: "worktree"
prompt: |
  あなたは Issue 解決担当のサブエージェントです。
  隔離された worktree 内で作業しています。

  ## 対象 Issue
  - 番号: #<number>
  - タイトル: <title>
  - 内容: <body の要約>

  ## ブランチ
  - ベース: origin/dev（なければ origin/main）
  - ブランチ名: fix/<issue-slug> または feature/<issue-slug>
    （Issue タイトルから英語ケバブケースで生成、50文字以内）

  ## 手順

  ### Step 1: 環境準備
  1. CLAUDE.md を読んでプロジェクト規約を確認
  2. `git fetch origin` して最新を取得
  3. `git checkout -b <branch-name> origin/dev` でブランチ作成

  ### Step 2: 調査
  1. Issue に関連するコードを Explore/Grep/Read で調査
  2. 根本原因を特定
  3. 修正方針を決定

  ### Step 3: 実装
  1. 修正方針に従ってコードを変更
  2. 必要に応じてテストを追加（テスト命名規約: test_<action>_<condition>_<expected_result>）
  3. CLAUDE.md のコーディング規約に従う

  ### Step 4: 検証
  1. lint を実行:
     - Backend: `ruff check backend/`
     - Frontend: `pnpm -C frontend run lint && pnpm -C frontend run type-check`
  2. テストを実行:
     - Backend: `cd backend && pytest`
     - Frontend: `pnpm -C frontend run test:unit`
  3. 失敗したら修正して再実行（最大3回）
  4. 3回失敗したら失敗内容を報告して終了

  ### Step 5: コミット & プッシュ
  1. 変更をコミット（メッセージは日本語、具体的に記述）
     - 複数テーマなら分割コミット
     - 「レビュー対応」等の曖昧メッセージ禁止
  2. `git push -u origin <branch-name>`

  ### Step 6: PR 作成
  ```bash
  gh pr create \
    --base dev \
    --title "<type>: <具体的な説明>" \
    --body "$(cat <<'BODY'
  ## Summary
  - <変更内容>

  ## Related Issue
  Closes #<number>

  ## Testing
  - [ ] lint pass
  - [ ] tests pass

  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  BODY
  )" \
    --assignee @me
  ```

  ### 出力形式
  最後に以下の形式で結果を報告:
  ```
  RESULT:
  - issue: #<number>
  - status: SUCCESS | FAILED
  - branch: <branch-name>
  - pr_url: <PR URL> (成功時のみ)
  - commits: <コミット数>
  - files_changed: <変更ファイル数>
  - tests: PASS | FAIL
  - failure_reason: <失敗理由> (失敗時のみ)
  ```

  ## 禁止事項
  - dev/main ブランチに直接コミットしない
  - テスト未通過でコミットしない
  - Issue の範囲外の変更をしない
  - 曖昧なコミットメッセージを書かない
```

### 3-2. 結果の収集

全エージェントの完了を待ち、結果を収集する。

---

## Phase 4: 結果報告

### 4-1. サマリー表示

```
=== Resolve Issues: Complete ===

## 結果
| #   | タイトル                  | ステータス | PR                | テスト |
|-----|--------------------------|----------|-------------------|-------|
| #12 | XXXのバリデーションエラー   | ✅ SUCCESS | <PR URL>          | PASS  |
| #15 | YYYの一覧が空になる        | ✅ SUCCESS | <PR URL>          | PASS  |
| #20 | ZZZのテストが不安定        | ❌ FAILED  | -                 | FAIL  |

## 失敗した Issue
### #20: ZZZのテストが不安定
失敗理由: <エージェントからの報告>
ブランチ: <branch-name>（手動で対応可能）

## Next Steps
- 各 PR は `/review-loop` でレビューできます
- 失敗した Issue は手動で個別に対応できます
```

---

## Critical Constraints

- **Phase 2 のユーザー承認なしで実装に入らない**（`--dry-run` 時は表示のみ）
- **全エージェントを並列で起動する**（逐次起動は禁止）
- **各エージェントは独立した worktree で作業する**（メインの作業ディレクトリを汚さない）
- **テスト通過を確認してから PR を作成する**
- **dev ブランチをベースにする**（存在しない場合は main にフォールバック）
- **同時処理数の上限を守る**（デフォルト 3、`--limit` で変更可能）
- **コンテキスト管理: Phase 境界で 80% チェック → `/compact`**

---

## Red Flags - Never Do This

- **Issue を分析せずにいきなり実装を始めない**
- **競合する Issue を同時に着手しない**
- **アサイン済みの Issue を横取りしない**
- **main/dev に直接コミットしない**
- **テスト未通過で PR を作成しない**
- **ユーザー承認前に worktree を作成しない**
- **エージェントを逐次起動しない（並列起動必須）**
