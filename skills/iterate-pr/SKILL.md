---
name: iterate-pr
description: PRの未解決コメントを取得し、妥当性判断(Agent) → Plan作成 → Codexレビューループ → ユーザー承認 → Codex実装 → クロス確認 → Post-Fixの一連フロー。
---

# Iterate PR

PRの未解決レビューコメントを全件取得し、**妥当性を判断してから対応**するスキル。
TRIAGE(Agent) → Plan → Codexレビュー → ユーザー承認 → Codex実装 → クロス確認 → Post-Fix の流れで進める。

**鉄則: どんな些細なコメントでも「無視」はしない。修正・Issue作成・返信のいずれかで必ず対応する。**

**Announce at start:** "iterate-pr を開始します。"

**コンテキスト管理:** 各ステップ開始前に80%超えなら `/compact` を実行。

---

## Step 1: Worktree作成

```bash
BRANCH=${ARGUMENTS:-$(git branch --show-current)}
```

Skill tool で `/create-worktree $BRANCH` を呼び出し、worktree に移動。以降の全作業はこの worktree 内で行う。

---

## Step 2: 未解決コメント取得・分類・妥当性判断（サブエージェント）

**CCは妥当性判断を行わない。** triage エージェントに委託し、結果サマリーと `.claude/pr-context.md` を受け取る。

Agent tool で起動する:

```
description: "triage: classify and judge PR comments"
prompt: |
  あなたはPRレビューコメントの妥当性を判断するサブエージェントです。

  ## タスク

  ### Step 1: 未解決コメント取得
  `$HOME/.claude/skills/iterate-pr/references/graphql-query.md` のクエリを使って
  未解決スレッドを全件取得する。0件なら「未解決コメントなし」と返す。

  ### Step 2: スレッド分類

  | 種別 | 条件 | 処理 |
  |------|------|------|
  | 既存返信あり (comment_count >= 2) | 最後が承認・了解 | resolve候補 |
  | | 最後が追加指摘 | 妥当性判断へ |
  | | 最後がIssue提案 | Issue作成候補 |
  | 新規 (comment_count == 1) | — | 妥当性判断へ |

  迷ったら「追加指摘」として妥当性判断に回す。

  ### Step 3: 妥当性判断
  各コメントについて:
  1. **対象コードを Read tool で読む**（必須）
  2. **CLAUDE.md を読む**
  3. **CODING_STANDARDS.md があれば読む**
  4. 判定:

  | 判定 | 基準 | 対応 |
  |------|------|------|
  | **妥当** | バグ・ルール違反・型安全性・命名不備 | 修正する |
  | **妥当だがスコープ外** | PR変更範囲外 | ファイル内完結→修正 / 大規模→Issue |
  | **妥当でない** | 事実と異なる・ルールと矛盾・意図的設計 | 返信する |

  「スコープ外なので対応しません」で終わるのは禁止。

  ### Step 4: pr-context.md 書き出し
  `$HOME/.claude/skills/iterate-pr/references/pr-context-template.md` のテンプレートに従い、
  `.claude/pr-context.md` を Write tool で書き出す。

  `レビュー観点候補` は「なぜセルフレビューで見落としたか」「次回どう検出するか」を考えて書く。

  ### Step 5: 結果レポート
  以下の形式で返す:

  ## Triage Result
  - 未解決コメント総数: N件
  - resolve候補: N件
  - 妥当（修正対象）: N件
  - スコープ外: N件（修正: N / Issue: N）
  - 妥当でない（返信対象）: N件
  - Issue作成候補: N件

  ### 妥当でないコメント
  | # | comment_id | ファイル | 行 | 投稿者 | コメント概要 | 妥当でない理由 | 返信文案 |
  |---|-----------|---------|-----|--------|------------|--------------|---------|

  `.claude/pr-context.md` に全分類結果を書き出し済み。
```

#### 2-1. 結果の確認

triage エージェントのサマリーを確認:

```
=== Step 2: TRIAGE ===
未解決: <N>件 → 妥当: <M>件 / スコープ外: <K>件 / 妥当でない: <L>件 / resolve: <R>件
```

**妥当 + スコープ外が0件 → resolve候補をresolve → 完了レポートへ**

#### ↓ コンテキスト確認 → 80% 以上なら `/compact`

---

## Step 3: ユーザー確認（妥当でないコメント）+ Plan作成

### 3-1. 妥当でないコメントを提示

triage エージェントが返した「妥当でないコメント」テーブルをユーザーに提示:

```
| # | ファイル | 行 | 投稿者 | コメント概要 | 妥当でない理由 | 返信文案 |
|---|---------|-----|--------|------------|--------------|---------|
```

ユーザーが返信文案を修正・承認するまで待つ。

### 3-2. Plan Mode で修正計画を作成

**テンプレート:** `references/plan-template.md`

プランに含める項目:
- **Goal**: 各コメントに対して何を修正するか
- **Scope**: 変更対象ファイル一覧（絶対パス付き）
- **Steps**: 順序付きの修正ステップ（各ステップに具体的な変更方針）
- **Testing strategy**: 追加/変更するテスト
- **Verification**: 各ステップの検証方法

プランを `.claude/plan.md` に保存する。

**この時点ではコードを一切変更しない。Plan Mode を終了して Step 4 へ。**

#### Context check -> `/compact` if >= 80%

---

## Step 4: Codex レビューループ

`.claude/plan.md` を Codex に送ってレビューを受け、LGTM が出るまで繰り返す。

### 4-1. レビュー用プロンプトの構築と送信

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"
PLAN_FILE=".claude/plan.md"

PROMPT=$(mktemp /tmp/iterate-pr-review.XXXXXX)

echo "# Project Rules" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Implementation Plan to Review\n" >> "$PROMPT"
cat "$PLAN_FILE" >> "$PROMPT"
echo -e "\n---\n# PR Context\n" >> "$PROMPT"
cat .claude/pr-context.md >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << 'REVIEW_INSTRUCTIONS' >> "$PROMPT"
You are reviewing an implementation plan that addresses PR review comments.
Evaluate it against these criteria:

1. **Architectural correctness**: Does it follow the project's existing patterns and conventions?
2. **Completeness**: Does each review comment get properly addressed?
3. **Step ordering**: Are dependencies between steps respected?
4. **Testing coverage**: Are adequate tests planned with proper naming?
5. **Risk assessment**: Are potential breaking changes identified?
6. **Scope appropriateness**: Is the plan appropriately scoped — not over-engineered, not under-specified?

If the plan is solid and ready for implementation, respond with exactly: LGTM

If there are issues, list them concisely with specific suggestions for improvement.
Each issue should be actionable — state what to change, not just what's wrong.
REVIEW_INSTRUCTIONS

codex review - < "$PROMPT"
rm -f "$PROMPT"
```

### 4-2. 結果の解析

- **LGTM（またはアクショナブルな指摘なし）**: Step 5 へ
- **指摘あり**: 4-3 のプラン修正エージェントへ

### 4-3. プラン修正（サブエージェント）

指摘がある場合、Agent tool でプラン修正エージェントを起動する:

```
description: "plan revision agent"
prompt: |
  あなたはプラン修正のサブエージェントです。

  ## Codex からの指摘:
  <Codex の出力をここに貼る>

  ## タスク:
  1. `.claude/plan.md` を Read tool で読む
  2. プロジェクトの CLAUDE.md を読む（規約確認用）
  3. 指摘を一つずつ検討し、プランを修正する
  4. 修正後のプランを `.claude/plan.md` に Edit tool で書き戻す
  5. 修正内容のサマリーを返す（何をどう変えたか）

  プランの修正のみ行い、コードは一切変更しないこと。
```

修正サマリーを記録し、再度 4-1 に戻る。

### 4-4. ループ制御

- **最大 5 ラウンド**
- 5 ラウンド後も指摘が残る場合: 残りの懸念事項をユーザーに提示して判断を仰ぐ

### 4-5. ラウンドサマリー

各ラウンド後に表示:

```
=== Codex Plan Review: Round <N>/<5> ===
Status: LGTM / <N>件の指摘あり
修正内容: <修正のサマリー>（修正した場合）
```

#### Context check -> `/compact` if >= 80%

---

## Step 5: ユーザー承認

### 5-1. Codex 承認済みプランの提示

`.claude/plan.md` の内容を全文表示する:

```
=== Codex-Approved Plan ===
Codex review rounds: <N>

<plan.md の全文>
```

### 5-2. ユーザーの判断を待つ

**ユーザーが承認するまで一切コードを変更しない。**

- **OK / 承認 / LGTM**: Step 6 へ（実装方法も選択）
- **修正要望あり**: プランを修正 → Step 4 に戻って Codex 再レビュー（ラウンドカウントはリセット）
- **却下 / キャンセル**: `.claude/plan.md` と `.claude/pr-context.md` を削除してスキル終了

承認時に実装方法を確認する:

```
実装方法を選んでください:
1. Codex CLI（codex cliで実装）[デフォルト]
2. Claude Code（このまま実装）
```

---

## Step 6: 実装

### 6-A: Codex CLI（デフォルト）

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"
PLAN_FILE=".claude/plan.md"

PROMPT=$(mktemp /tmp/iterate-pr-exec.XXXXXX)

echo "# Project Rules (MUST follow)" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Implementation Plan\n" >> "$PROMPT"
cat "$PLAN_FILE" >> "$PROMPT"
echo -e "\n---\n# PR Context\n" >> "$PROMPT"
cat .claude/pr-context.md >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << 'EXEC_INSTRUCTIONS' >> "$PROMPT"
Implement the above plan exactly as specified. This plan addresses PR review comments.

Rules:
1. Implement all steps in the order specified
2. Follow the project conventions in the Project Rules strictly
3. Add all planned tests
4. Run tests after implementation to verify correctness
5. Do not deviate from the plan — implement exactly what is specified
6. Do not add extra features, refactoring, or improvements beyond the plan
EXEC_INSTRUCTIONS

codex - < "$PROMPT"
rm -f "$PROMPT"
```

### 6-B: Claude Code

Plan に従いコードを修正する。修正後、テスト通過を確認。

#### Context check -> `/compact` if >= 80%

---

## Step 7: クロス確認

**実装者と確認者を常に別にする。**

- **Codex で実装した場合（6-A）** → Claude Code で確認（7-A）
- **Claude Code で実装した場合（6-B）** → Codex で確認（7-B）

### 7-A: Claude Code で確認（Codex実装時）

#### 7-A-1. 差分とプランの照合

1. `git diff` で全差分を確認
2. `.claude/plan.md` を読み、プランの全ステップが実装されているか確認
3. `.claude/pr-context.md` の各レビューコメントに対して、対応する修正が入っているか確認

#### 7-A-2. テスト実行

```bash
# Backend
cd backend && pytest

# Frontend（変更がある場合）
pnpm -C frontend run type-check && pnpm -C frontend run lint && pnpm -C frontend run test:unit
```

#### 7-A-3. 確認結果の報告

```
=== Implementation Verification (by Claude Code) ===

レビューコメント対応状況:
| # | コメント概要 | 対応状況 | 備考 |
|---|------------|---------|------|
| 1 | ... | ✅ 対応済 | ... |
| 2 | ... | ❌ 未対応 | ... |

テスト結果:
- Backend: PASS / FAIL
- Frontend: PASS / FAIL / SKIP
```

#### 7-A-4. 未対応・問題があった場合

未対応のコメントや失敗テストがある場合、Claude Code で直接修正する。
修正後、再度テスト実行で通過を確認。

### 7-B: Codex で確認（Claude Code実装時）

#### 7-B-1. 確認用プロンプトの構築と送信

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"
PLAN_FILE=".claude/plan.md"
DIFF=$(git diff HEAD~1)

PROMPT=$(mktemp /tmp/iterate-pr-verify.XXXXXX)

echo "# Project Rules" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Implementation Plan\n" >> "$PROMPT"
cat "$PLAN_FILE" >> "$PROMPT"
echo -e "\n---\n# PR Context (review comments to address)\n" >> "$PROMPT"
cat .claude/pr-context.md >> "$PROMPT"
echo -e "\n---\n# Actual Diff\n" >> "$PROMPT"
echo "$DIFF" >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << 'VERIFY_INSTRUCTIONS' >> "$PROMPT"
You are verifying that an implementation correctly addresses PR review comments.

Check:
1. Does each review comment in the PR Context get properly addressed by the diff?
2. Are there any missing changes that the plan specified but the diff doesn't include?
3. Are there extra changes not in the plan?
4. Are there any bugs or issues in the implementation?

If everything looks good, respond with: LGTM

If there are issues, list them with specific details about what needs to be fixed.
VERIFY_INSTRUCTIONS

codex review - < "$PROMPT"
rm -f "$PROMPT"
```

#### 7-B-2. 結果の解析

- **LGTM**: Step 7-C へ
- **指摘あり**: Claude Code で修正 → 再度 Codex 確認（最大 3 ラウンド）

### 7-C: コミット＆プッシュ

全確認が通ったら `/commit-push` でコミット＆プッシュ。

---

## Step 8: Post-Fix（3つの Agent を並列実行）

修正・コミット完了後、以下の3つの Agent を **並列で** 起動する。

`.claude/pr-context.md` を各 Agent のプロンプトに含めること（Agent は親のコンテキストを持たないため）。

### Agent A: 修正コメントへの返信

**プロンプトに含める情報:** Owner/Repo、修正した各 comment_id、対応するコミットハッシュ

```
pr-context.md の「妥当なコメント（修正対象）」セクションを読み、
各 comment_id に対して以下を実行:

gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  --method POST --field body="Fixed in {commit_hash}"
```

### Agent B: 妥当でないコメントへの返信

**プロンプトに含める情報:** Owner/Repo、各 comment_id、返信文案

```
pr-context.md の「妥当でないコメント（返信対象）」セクションを読み、
各 comment_id に対して返信文案の内容で返信:

gh api repos/{owner}/{repo}/pulls/comments/{comment_id}/replies \
  --method POST --field body="{返信文案}"
```

### Agent C: レビュースキルへの観点追加

**プロンプトに含める情報:** PR番号、各修正の「レビュー観点候補」「対象スキル」「対象カテゴリ」

```
pr-context.md の各修正コメントの「レビュー観点候補」を読み、
対象のチェックリストファイルに追記:

- backend/ の指摘 → ~/claude-dotfiles/skills/backend-coderabbit/checklists/ 配下の該当カテゴリファイル:
  - Architecture/Code Organization/Syntax 関連 → checklists/architecture.md
  - Type Safety/Validation/Error Handling 関連 → checklists/type-safety.md
  - DB Performance/Migration 関連 → checklists/db-performance.md
  - Test Quality 関連 → checklists/test-quality.md
  - Security/Error Messages 関連 → checklists/security-errors.md

- frontend/ の指摘 → ~/claude-dotfiles/skills/frontend-coderabbit/checklists/ 配下の該当カテゴリファイル:
  - FSD Architecture/Code Organization/Unused Code/Syntax 関連 → checklists/fsd-architecture.md
  - Type Safety/State Management 関連 → checklists/type-state.md
  - Error Handling/Vue.js Patterns 関連 → checklists/error-vue.md
  - TanStack Query/Security 関連 → checklists/tanstack-security.md
  - Test Quality 関連 → checklists/test-quality.md

フォーマット:
  - **<観点名>** — <チェック内容>。<理由>。<対策>。

該当カテゴリのExtended Checklistセクションの末尾に追記。
追記後:
  cd ~/claude-dotfiles && git add skills/ && git commit -m "feat: PR#<number>の指摘からレビュースキルに観点を追加" && git push
```

### 全 Agent 完了後

```bash
rm -f .claude/pr-context.md .claude/plan.md
```

---

## 完了レポート

```
=== Iterate PR Complete ===

未解決コメント総数: <N>件
Codex review rounds: <N>

対応結果:
  修正:       <N>件（うちスコープ外修正: <N>件）
  Issue作成:  <N>件
  返信:       <N>件（妥当でない旨）
  resolve:    <N>件（承認済みスレッド）
  観点追加:   <N>件（backend: N / frontend: N）

コミット一覧:
  - <hash>: <message>
  - (claude-dotfiles) <hash>: <message>
```

---

## Red Flags

- **CCが直接妥当性判断しない** — triage エージェントに委託する
- コメントを読まずに妥当性を判断しない — エージェントが必ず対象コードを Read tool で読んでから
- 「対応不要」「スキップ」「スコープ外なので無視」で片付けない — 全件、修正・Issue作成・返信のいずれか
- 既存返信ありスレッドの会話の流れを無視しない — スレッド全体を読んでから判断
- 承認済みスレッドを放置しない — 速やかに resolve
- 「PRレビュー対応」等の抽象的なコミットメッセージを使わない
- テストが失敗したままコミットしない
- 妥当でないと判断した場合、ユーザー確認なしにPRへ返信しない — Step 3 で必ず確認
- **ユーザー承認なしで Step 6 に進まない**
- **Codex の出力を読まずに「LGTM」と判定しない**
- **`codex` / `codex review` のプロンプトに CLAUDE.md を含めずに実行しない**
- **実装者と確認者を同じにしない** — Codex実装→Claude Code確認、Claude Code実装→Codex確認
