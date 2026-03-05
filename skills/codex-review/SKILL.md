---
name: codex-review
description: Codex CLIを使ってコードレビューを非インタラクティブに実行するスキル。coderabbit-review または sora-review スタイルの指示を codex review に渡してレビューを行う。
---

# Codex Review

Codex CLI (`codex review`) を非インタラクティブに呼び出し、プロジェクトのレビュー規約に沿ったコードレビューを実行する。

**Announce at start:** "codex-review スキルで Codex CLI によるコードレビューを実行します"

## Review Style Selection

ユーザーがスタイルを指定していない場合は確認する:
- **coderabbit**: フォーマル・体系的・包括的（デフォルト）
- **sora**: カジュアル・直接的・会話的

## Step 1: Build Prompt File

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

## Step 2: Run Codex Review

```bash
# dev ブランチとの差分をレビュー
codex review --base dev - < "$PROMPT_FILE"

# クリーンアップ
rm "$PROMPT_FILE"
```

### オプション

| 用途 | コマンド |
|------|---------|
| dev ブランチとの差分 | `codex review --base dev - < "$PROMPT_FILE"` |
| ステージング+未ステージ変更 | `codex review --uncommitted - < "$PROMPT_FILE"` |
| 特定コミット | `codex review --commit <SHA> - < "$PROMPT_FILE"` |

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
