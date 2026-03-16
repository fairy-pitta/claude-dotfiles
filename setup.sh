#!/bin/bash
# Claude Code Dotfiles Setup Script
# Run this on a new machine to set up Claude Code configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "🚀 Setting up Claude Code configuration..."

# Create directories
echo "📁 Creating directories..."
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/scripts"
mkdir -p "$CLAUDE_DIR/skills"

# Copy configuration files
echo "📄 Copying configuration files..."
cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/" 2>/dev/null || echo "  - settings.json not found, skipping"
cp "$SCRIPT_DIR/settings.local.json" "$CLAUDE_DIR/"

# Copy commands
echo "📝 Copying custom commands..."
if compgen -G "$SCRIPT_DIR/commands/"*.md > /dev/null 2>&1; then
  cp "$SCRIPT_DIR/commands/"*.md "$CLAUDE_DIR/commands/"
else
  echo "  - No custom commands found, skipping"
fi

# Copy scripts and make executable
echo "🔧 Copying hook scripts..."
cp "$SCRIPT_DIR/scripts/"*.sh "$CLAUDE_DIR/scripts/"
chmod +x "$CLAUDE_DIR/scripts/"*.sh

# Copy statusline script
echo "📊 Copying statusline script..."
cp "$SCRIPT_DIR/scripts/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"

# Symlink custom skills (auto-syncs when repo is updated)
echo "🎯 Symlinking custom skills..."
for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$CLAUDE_DIR/skills/$skill_name"
  if [ -L "$target" ] || [ -e "$target" ]; then
    rm -rf "$target"
  fi
  ln -s "$SCRIPT_DIR/skills/$skill_name" "$target"
  echo "  - $skill_name -> symlinked"
done

# Symlink standalone skill files (*.md directly in skills/)
for skill_file in "$SCRIPT_DIR/skills/"*.md; do
  [ -f "$skill_file" ] || continue
  skill_basename="$(basename "$skill_file")"
  target="$CLAUDE_DIR/skills/$skill_basename"
  if [ -L "$target" ] || [ -e "$target" ]; then
    rm -rf "$target"
  fi
  ln -s "$SCRIPT_DIR/skills/$skill_basename" "$target"
  echo "  - $skill_basename -> symlinked"
done

# Clone Superpowers (if not already present)
if [ ! -d "$CLAUDE_DIR/skills/superpowers" ]; then
  echo "⚡ Installing Superpowers skills..."
  git clone https://github.com/obra/superpowers.git "$CLAUDE_DIR/skills/superpowers"
else
  echo "⚡ Superpowers already installed, updating..."
  cd "$CLAUDE_DIR/skills/superpowers" && git pull
fi

# Set up MCP servers
echo "🔌 Setting up MCP servers..."
if command -v claude &> /dev/null; then
  claude mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null || echo "  - Playwright MCP may already be configured"

  if command -v uvx &> /dev/null; then
    claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code --project "$(pwd)" 2>/dev/null || echo "  - Serena MCP may already be configured"
  else
    echo "  ⚠️  uv not installed. Install it for Serena MCP: curl -LsSf https://astral.sh/uv/install.sh | sh"
  fi
else
  echo "  ⚠️  Claude Code not found. Install it first: npm install -g @anthropic-ai/claude-code"
fi

# Create Claude Code working directory
echo "📂 Creating Claude Code working directory..."
mkdir -p "$HOME/Claude Code"/{notes,analysis,research,dev,skills}
touch "$HOME/Claude Code/CLAUDE.md"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Installed:"
echo "  - Custom commands (9 commands)"
echo "  - Custom skills (symlinked from dotfiles/skills/)"
echo "  - Hook scripts (auto-format, deny-check)"
echo "  - Status line (3-line rate limit display)"
echo "  - Superpowers skills (14 skills)"
echo "  - MCP servers (Playwright, Serena)"
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code to load new configuration"
echo "  2. Run '/mcp' to verify MCP servers"
echo "  3. Type '/' to see available commands"
