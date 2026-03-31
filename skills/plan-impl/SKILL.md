---
name: plan-impl
description: コードベース調査 → 要件壁打ち → 設計書作成 → チェックリスト検証までの着手前設計スキル。実装には進まない。（デフォルト: CC Agent、--codex で codex CLI）
---

# Design

新機能や大きな変更に着手する **前** に、コードベースを深く調査し、ユーザーと壁打ちしながら設計書を完成させるスキル。
**このスキルは設計書の完成で終了し、実装には進まない。**

Context: $ARGUMENTS

**開始時アナウンス:** "design を開始します。コードベース調査 → 要件壁打ち → 設計書作成 → チェックリスト検証 の流れで進めます。"

## エンジン選択

`$ARGUMENTS` に `--codex` が含まれる場合は codex CLI を壁打ち相手として使用する。それ以外は **Claude Code Agent（デフォルト）** を使用する。

```
USE_CODEX = "--codex" in $ARGUMENTS
```

---

## コンテキスト管理（最優先ルール）

**各フェーズ境界でコンテキスト使用率を確認し、80% 以上なら `/compact` してから続行する。**

---

## Phase 1: 要件の取得

### 1-1. 入力の解釈

- `$ARGUMENTS` に GitHub Issue 番号/URL がある場合: `gh issue view` で取得
- `$ARGUMENTS` にインライン指示がある場合: そのまま要件として使用
- `$ARGUMENTS` が空の場合: ユーザーに何を作るか確認

### 1-2. 要件の要約

取得した情報から以下を整理してユーザーに提示する:

- **何を作る/変えるのか（What）**
- **なぜ必要か（Why）**
- **誰が使うか（Who）**
- **成功の定義（受け入れ条件の素案）**

ユーザーに「この理解で合っていますか？」と確認する。

---

## Phase 2: コードベース深掘り調査

### 2-1. 調査（Explore エージェント）

Agent tool で Explore エージェントを **very thorough** レベルで起動する:

```
subagent_type: "Explore"
description: "deep codebase research for design"
prompt: |
  以下の要件に関連するコードベースを徹底的に調査してください。
  表面的な読みではなく、実装の詳細まで深く理解すること。

  ## 要件
  <Phase 1 で整理した要件>

  ## 調査観点
  1. **全体アーキテクチャ**: ディレクトリ構成、レイヤー構造、主要モジュールの関係
  2. **ドメインのフォルダ構成**: 対象ドメインのファイル・クラス・関数の一覧と役割
  3. **関連する既存実装**: 類似機能があれば、そのパターンを詳細に記載
  4. **設計パターンと規約**: 命名規則、依存方向、DI パターン、エラーハンドリング方針
  5. **テストの構造と規約**: テストディレクトリ、命名規則、フィクスチャの使い方
  6. **外部依存**: 使用中のライブラリ・フレームワークで今回の要件に関連するもの
  7. **危険ゾーン**: 変更すると影響が大きい箇所、密結合している部分

  ## 出力形式
  各観点について、ファイルパスと概要を付けて簡潔にまとめる。
  コード例は不要。パス・クラス名・関数名と、その役割の説明のみ。
```

### 2-2. 調査結果の記録

Explore エージェントの結果を `.claude/research.md` に保存する。

### 2-3. 調査結果をユーザーに提示

調査結果のサマリーを表示し、ユーザーに以下を確認する:

```
=== Phase 2: コードベース調査完了 ===

## アーキテクチャ概要
<主要な構造>

## 関連ファイル
<変更候補のファイル群>

## 類似実装
<参考になるパターン>

## 注意点
<密結合・影響範囲が大きい箇所>

この調査結果に補足・修正はありますか？
```

#### Context check -> `/compact` if >= 80%

---

## Phase 3: 要件壁打ち（ブレスト）

**ユーザーと AI が対話しながら要件・設計方針を練り上げるフェーズ。**
壁打ちは **ユーザーが「OK」「LGTM」「これでいい」と明示するまで** 繰り返す。

### 3-1. 壁打ち開始

Phase 1-2 の結果をもとに、AI 側から設計の論点を提示する。

提示する論点の例:

- **アプローチの選択肢**: 実現方法が複数ある場合、各案のメリット/デメリット
- **スコープの確認**: MVP として必要な範囲と、後回しにできる部分
- **既存パターンとの整合性**: 調査で見つけた既存パターンに従うか、新パターンを導入するか
- **依存関係**: 新たに追加が必要なライブラリがあるか、その理由は妥当か
- **エッジケース**: 考慮すべき例外パターン
- **テスト戦略**: 何をどのレベルでテストするか

### 3-2. 壁打ちループ

#### 3-2-A: Claude Code Agent（デフォルト）

ユーザーの発言に対して、以下の姿勢で応答する:

1. **具体的な質問で返す** — 「どうしますか？」ではなく「A案とB案があります。A案は○○で、B案は○○。どちらが合いますか？」
2. **コードベースの事実に基づく** — `.claude/research.md` の調査結果を根拠に議論する
3. **懸念点は率直に指摘** — 「この方針だと○○のリスクがあります」と具体的に
4. **ユーザーの決定を尊重** — 最終判断はユーザーに委ねる
5. **決まった事項はメモする** — 壁打ち中に決まった設計方針を随時記録する

#### 3-2-B: codex CLI との壁打ち（--codex 指定時）

ユーザーの論点や質問を codex CLI に投げてセカンドオピニオンを得る:

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"

PROMPT=$(mktemp /tmp/design-brainstorm.XXXXXX)

echo "# Project Rules" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Codebase Research\n" >> "$PROMPT"
cat .claude/research.md >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << BRAINSTORM_PROMPT >> "$PROMPT"
あなたはシニアエンジニアとして設計の壁打ち相手を務めます。

## 要件
<要件の要約>

## 現在の論点
<ユーザーの質問や議論中のポイント>

以下の観点で意見を述べてください:
1. 提案されたアプローチの妥当性
2. 見落としているリスクや代替案
3. コードベースの既存パターンとの整合性
4. 簡潔な推奨（1つに絞る）

簡潔に、具体的に答えること。
BRAINSTORM_PROMPT

codex review - < "$PROMPT"
rm -f "$PROMPT"
```

codex の回答をユーザーに提示し、議論を続ける。

### 3-3. 壁打ち完了判定

ユーザーが以下のいずれかを発言したら壁打ち終了:

- 「OK」「LGTM」「これでいい」「進めて」「設計書にして」
- 明確な承認の意思表示

壁打ちで決まった設計方針を箇条書きで整理し、ユーザーに最終確認:

```
=== 壁打ち結果サマリー ===

## 決定事項
- <決定1>
- <決定2>
- ...

## スコープ
- IN:  <含めるもの>
- OUT: <含めないもの>

## 技術方針
- <方針1>
- <方針2>

この内容で設計書を作成します。よろしいですか？
```

#### Context check -> `/compact` if >= 80%

---

## Phase 4: 設計書作成

### 4-1. 設計書の作成

`references/design-template.md` のテンプレートに従い、`.claude/design.md` を作成する。

**設計書に含める項目:**

1. **背景（Background）**: なぜこの変更が必要か
2. **方針（Approach）**: 壁打ちで決まった技術方針
3. **変更ファイル一覧（Scope）**: 各ファイルの変更内容の概要（パス付き）
4. **実装ステップ（Phases）**: 順序付きの実装計画
5. **受け入れ条件（Acceptance Criteria）**: 完了の定義（テスト可能な形式で記述）
6. **テスト戦略（Testing Strategy）**: 追加するテスト（関数名の命名案付き）
7. **リスクと対策（Risks）**: 破壊的変更、パフォーマンス、マイグレーションのリスク
8. **品質チェックリスト（Quality Checklist）**: `references/quality-checklist.md` を埋める

### 4-2. 設計書レビュー

#### 4-2-A: Claude Code Agent（デフォルト）

Agent tool で起動する:

```
description: "design doc review agent"
prompt: |
  あなたは設計書レビューのサブエージェントです。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. `.claude/design.md` を読む
  3. `.claude/research.md` を読む
  4. `references/design-review-points.md` を読む（設計段階で確認すべきレビュー観点）
  5. 以下の基準で評価する:

  ### 設計品質
  - 背景・方針が明確で、なぜこのアプローチを選んだか説明されているか
  - 変更ファイル一覧が網羅的で、漏れがないか
  - 受け入れ条件がテスト可能な形式で記述されているか
  - 既存の設計パターンと整合しているか

  ### 品質チェックリスト（着手前）
  - 設計書に背景・方針・変更ファイル一覧・受け入れ条件が揃っているか
  - ドメインのフォルダ構成が明示されているか

  ### 品質チェックリスト（実装中 — 設計段階での検証）
  - 計画している関数名・変数名から中身が推測できるか
  - 各関数が単一責務を担う設計になっているか
  - 同じロジックの3箇所以上コピペが発生しない設計か
  - 新規依存追加がある場合、その理由が説明されているか

  ### 品質チェックリスト（提出前 — 設計段階での検証）
  - 変更に対応するユニットテストが計画されているか
  - 受け入れ条件が全て検証可能か

  ### レビュー観点による設計チェック（design-review-points.md 準拠）
  変更対象がbackend/frontendのどちらかに応じて、該当する観点を適用する:

  **Backend変更がある場合:**
  - アーキテクチャ: Feature間依存・Domain層純粋性・Application層ORM非依存・Transaction配置
  - DB/パフォーマンス: N+1回避・SELECT*禁止・インデックス設計
  - 型安全: Result型採用・Enum必須・バリデーション順序
  - セキュリティ: permission_classes明示・認可バイパス排除
  - エラーメッセージ: 定数化・ユーザー向け/内部向け分離

  **Frontend変更がある場合:**
  - FSD: 依存方向・index.ts経由・features間import禁止・昇格ルール
  - 型安全: any禁止・enum禁止・型アサーション禁止・toEntity変換
  - 状態管理: 3分類・Pinia禁止・readonly保護・バケツリレー防止
  - エラー: console禁止・4層パイプライン・Zodバリデーション

  **テスト設計:**
  - 命名規約・正常系+異常系網羅・境界値・N+1検証・認可テスト・副作用否定テスト

  プランが良ければ: "LGTM" とだけ返す
  問題があれば: 具体的な改善提案を簡潔にリストする
```

#### 4-2-B: codex CLI（--codex 指定時）

```bash
CLAUDE_MD="$(pwd)/CLAUDE.md"

PROMPT=$(mktemp /tmp/design-review.XXXXXX)

DESIGN_REVIEW_POINTS="$HOME/.claude/skills/plan-impl/references/design-review-points.md"

echo "# Project Rules" > "$PROMPT"
[ -f "$CLAUDE_MD" ] && cat "$CLAUDE_MD" >> "$PROMPT"
echo -e "\n---\n# Codebase Research\n" >> "$PROMPT"
cat .claude/research.md >> "$PROMPT"
echo -e "\n---\n# Design Document to Review\n" >> "$PROMPT"
cat .claude/design.md >> "$PROMPT"
echo -e "\n---\n# Design Review Points (from review skills)\n" >> "$PROMPT"
[ -f "$DESIGN_REVIEW_POINTS" ] && cat "$DESIGN_REVIEW_POINTS" >> "$PROMPT"
echo -e "\n---\n" >> "$PROMPT"
cat << 'REVIEW_INSTRUCTIONS' >> "$PROMPT"
You are reviewing a design document before implementation begins.

Evaluate against these criteria:

## Design Quality
1. Is the background clear and the approach well-justified?
2. Is the file change list comprehensive with no omissions?
3. Are acceptance criteria written in testable form?
4. Does the design align with existing project patterns?

## Quality Checklist (Pre-implementation)
5. Does the design doc include: background, approach, changed files, acceptance criteria?
6. Is the domain folder structure explicitly documented?

## Quality Checklist (Implementation readiness)
7. Are planned function/variable names self-explanatory?
8. Does each planned function have a single responsibility?
9. Is the design free of 3+ copy-paste risk areas?
10. Are reasons for new dependency additions explained?

## Quality Checklist (Submission readiness)
11. Are unit tests planned for all changes?
12. Are all acceptance criteria verifiable?

## Design Review Points (from review skills)
Apply the relevant design-phase review points from the attached design-review-points.md:
- Backend: architecture (dependency direction, domain purity, transaction placement), DB/perf (N+1, index), type safety (Result, Enum), security (permissions, authz bypass), error messages (constants)
- Frontend: FSD (dependency direction, index.ts, features isolation), type safety (no any/enum/as), state management (3-classification, no Pinia, readonly), error handling (no console, 4-layer pipeline, Zod)
- Tests: naming, normal+error coverage, boundary values, N+1 assertions, authz tests, side-effect negation

If the design is solid, respond with exactly: LGTM
If there are issues, list them concisely with specific suggestions.
REVIEW_INSTRUCTIONS

codex review - < "$PROMPT"
rm -f "$PROMPT"
```

### 4-3. レビュー結果の解析

- **LGTM（またはアクショナブルな指摘なし）**: Phase 5 へ
- **指摘あり**: 設計書を修正し、再レビュー

### 4-4. 設計書修正（サブエージェント）

指摘がある場合、Agent tool で修正エージェントを起動する:

```
description: "design doc revision agent"
prompt: |
  あなたは設計書修正のサブエージェントです。

  ## レビューからの指摘:
  <レビューの出力をここに貼る>

  ## タスク:
  1. `.claude/design.md` を Read tool で読む
  2. `.claude/research.md` を Read tool で読む
  3. プロジェクトの CLAUDE.md を読む（規約確認用）
  4. 指摘を一つずつ検討し、設計書を修正する
  5. 修正後の設計書を `.claude/design.md` に Edit tool で書き戻す
  6. 修正内容のサマリーを返す（何をどう変えたか）

  設計書の修正のみ行い、コードは一切変更しないこと。
```

### 4-5. ループ制御

- **最大 5 ラウンド**
- 5 ラウンド後も指摘が残る場合: 残りの懸念事項をユーザーに提示して判断を仰ぐ

### 4-6. ラウンドサマリー

各ラウンド後に表示:

```
=== Design Review: Round <N>/<5> ===
Status: LGTM / <N>件の指摘あり
修正内容: <修正のサマリー>（修正した場合）
```

#### Context check -> `/compact` if >= 80%

---

## Phase 5: ユーザー承認と完了

### 5-1. 設計書の全文提示

`.claude/design.md` の内容を全文表示する:

```
=== Design Document ===
Review rounds: <N>

<design.md の全文>
```

### 5-2. 品質チェックリストの確認

`references/quality-checklist.md` の「着手前」チェック項目を表示し、全項目のステータスを報告:

```
=== 着手前チェックリスト ===
✅ 設計書（背景 / 方針 / 変更ファイル一覧 / 受け入れ条件）を書いた
✅ ドメインのフォルダ構成をAIに明示した
✅ 関数名・変数名だけで中身がわかる設計になっている
✅ 各関数が単一責務を担う設計になっている
✅ 同じロジックの3箇所以上コピペが発生しない設計になっている
✅ 依存追加の理由が説明されている
✅ 変更に対応するユニットテストが計画されている
✅ 受け入れ条件が全て検証可能である
```

未通過の項目がある場合は、ユーザーに報告してどうするか確認する。

### 5-3. ユーザーの判断を待つ

**ユーザーが承認するまで完了としない。**

- **OK / 承認 / LGTM**: 完了レポートを出力してスキル終了
- **修正要望あり**: 設計書を修正 → Phase 4 に戻って再レビュー（ラウンドカウントはリセット）
- **却下 / キャンセル**: `.claude/design.md` と `.claude/research.md` を削除してスキル終了

### 5-4. 完了レポート

```
=== Design Complete ===

設計書: .claude/design.md
調査結果: .claude/research.md
Review rounds: <N>
品質チェック: 全項目通過

## Next Steps
- 設計書をもとに実装を開始するには `/codex-plan` を実行
- 設計書の内容を確認するには `.claude/design.md` を参照
```

---

## Critical Constraints

- **このスキルは設計書の完成で終了する** — 実装には進まない
- **Phase 3 の壁打ちはユーザーが明示的に終了するまで続ける** — AI が勝手に切り上げない
- **コードを一切変更しない** — 設計書（.claude/design.md）と調査結果（.claude/research.md）のみ作成
- **ユーザー承認は必須** — レビュー LGTM だけでは完了としない
- **レビューは最大 5 ラウンド** — 無限ループ防止
- **コンテキスト管理: 各フェーズ境界で 80% チェック**
- **設計書修正はサブエージェントに委譲** — メインコンテキストの消費を最小限に抑える

---

## Red Flags - Never Do This

- **壁打ちフェーズをスキップしない** — ユーザーとの対話なしに設計書を作成しない
- **コードベース調査をスキップしない** — 既存実装を知らずに設計しない
- **ユーザー承認なしで完了としない**
- **設計書にコードを書かない** — 設計方針と受け入れ条件のみ。実装は `/codex-plan` に委ねる
- **品質チェックリストの未通過項目を無視しない** — 必ずユーザーに報告する
- **壁打ち中に「どうしますか？」だけで返さない** — 具体的な選択肢を提示する
- **codex 使用時にプロンプトに CLAUDE.md を含めずに実行しない**
