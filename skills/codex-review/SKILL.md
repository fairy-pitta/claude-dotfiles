---
name: codex-review
description: コードレビューを非インタラクティブに実行するスキル。coderabbit-review または sora-review スタイルの指示でレビューを行う。（デフォルト: CC Agent、--codex で codex CLI）
---

# Codex Review

プロジェクトのレビュー規約に沿ったコードレビューを実行する。

**Announce at start:** "codex-review スキルでコードレビューを実行します"

## エンジン選択

`$ARGUMENTS` に `--codex` が含まれる場合は codex CLI (`codex review`) を使用する。それ以外は **Claude Code Agent（デフォルト）** を使用する。

```
USE_CODEX = "--codex" in $ARGUMENTS
```

## Review Style Selection

ユーザーがスタイルを指定していない場合は確認する:
- **coderabbit**: フォーマル・体系的・包括的（デフォルト）
- **sora**: カジュアル・直接的・会話的

## Step 1-A: Claude Code Agent（デフォルト）

Agent tool で起動する:

```
description: "code review agent"
prompt: |
  あなたはコードレビューのサブエージェントです。

  ## タスク
  1. プロジェクトの CLAUDE.md を読む
  2. レビュースタイルファイルを読む: ~/.claude/skills/<coderabbit-review or sora-review>/SKILL.md
  3. 以下のコマンドで差分を取得:
     git diff origin/dev...HEAD
  4. レビュースタイルに従ってレビューを実行する

  レビュー結果を返す。
```

→ Step 3 へ

## Step 1-B: codex CLI（--codex 指定時）

レビュー指示をファイルに書き出す:

```bash
# スタイルに応じて SKILL.md を選択
STYLE="coderabbit"  # または "sora"

if [ "$STYLE" = "sora" ]; then
  SKILL_FILE="$HOME/.claude/skills/sora-review/SKILL.md"
else
  SKILL_FILE="$HOME/.claude/skills/coderabbit-review/SKILL.md"
fi

# CLAUDE.md + SKILL.md を結合してプロンプト作成
PROMPT_FILE=$(mktemp /tmp/codex-review-prompt.XXXXXX)
echo "# Project Rules (CLAUDE.md)" > "$PROMPT_FILE"
cat /Users/wao_singapore/forval-crossgear/CLAUDE.md >> "$PROMPT_FILE"
echo "" >> "$PROMPT_FILE"
echo "---" >> "$PROMPT_FILE"
echo "" >> "$PROMPT_FILE"
cat "$SKILL_FILE" >> "$PROMPT_FILE"
```

## Step 2: Run Codex Review（--codex 指定時のみ）

**重要:** `codex review` では `--base`/`--uncommitted`/`--commit` と `[PROMPT]`（stdin `-` 含む）は排他。
カスタムプロンプトを使う場合は diff をプロンプトに含め、`codex review -` で実行する。

```bash
# dev ブランチとの差分をプロンプトに追加
echo -e "\n---\n# Git diff (changes to review)\n" >> "$PROMPT_FILE"
git diff origin/dev...HEAD >> "$PROMPT_FILE"

# レビュー実行
codex review - < "$PROMPT_FILE"

# クリーンアップ
rm "$PROMPT_FILE"
```

### オプション

| 用途 | コマンド |
|------|---------|
| カスタムプロンプト + diff | diff をプロンプトに含めて `codex review - < "$PROMPT_FILE"` |
| dev ブランチとの差分（デフォルトレビュー） | `codex review --base dev` |
| ステージング+未ステージ変更（デフォルトレビュー） | `codex review --uncommitted` |
| 特定コミット（デフォルトレビュー） | `codex review --commit <SHA>` |

## Step 3: Show Output

Codex の出力をそのまま表示する。

## CodeRabbit CLI を使う場合（代替）

`coderabbit review` CLI でも同等のレビューが可能。`-c` で複数ファイルを直接渡せる:

```bash
CLAUDE_MD="/Users/wao_singapore/forval-crossgear/CLAUDE.md"
CODERABBIT_YAML="/Users/wao_singapore/forval-crossgear/coderabbit.yaml"
SKILL_FILE="$HOME/.claude/skills/coderabbit-review/SKILL.md"

# coderabbit.yaml があれば追加する
CR_YAML_ARG=""
[ -f "$CODERABBIT_YAML" ] && CR_YAML_ARG="-c $CODERABBIT_YAML"

coderabbit review --plain --base dev \
  -c "$CLAUDE_MD" \
  $CR_YAML_ARG \
  -c "$SKILL_FILE"
```

## Notes

- `codex review` / `coderabbit review` は git diff を自動取得するため、差分の手動準備は不要
- CLAUDE.md をコンテキストの先頭に含めることでプロジェクト固有のルールを渡す
- `coderabbit.yaml` はプロジェクトルートに存在する場合のみ渡す
- モデルは各 CLI のデフォルト設定を使用
