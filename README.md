# Claude Code Dotfiles

My Claude Code configuration for portable setup across machines.

## Quick Setup

```bash
git clone https://github.com/YOUR_USERNAME/claude-dotfiles.git ~/claude-dotfiles
cd ~/claude-dotfiles
./setup.sh
```

## What's Included

### Custom Commands (`commands/`)

| Command | Description |
|---------|-------------|
| `/fix-github-issue` | Analyze and fix GitHub issues |
| `/review-code` | Code review with suggestions |
| `/create-pr` | Create pull request |
| `/explain` | Explain code or concepts |
| `/refactor` | Refactor code |
| `/code-simplifier` | Simplify code (sub-agent) |
| `/verify-app` | E2E verification (sub-agent) |
| `/deep-research` | Deep research (sub-agent) |
| `/security-check` | Security analysis (sub-agent) |

### Hook Scripts (`scripts/`)

- `auto-format.sh` - Auto-format files after edit (Prettier/Black)
- `deny-check.sh` - Block dangerous commands

### Permissions (`settings.local.json`)

**Allowed:**
- File editing, git operations, npm commands
- Basic file operations (ls, mkdir, touch, open)

**Denied:**
- `rm -rf /*` - Dangerous deletion
- `chmod 777` - Insecure permissions
- `git config --global` - Global config changes
- `git push --force` - Force push

### MCP Servers

- **Playwright** - Browser automation
- **Serena** - Semantic code search

### Skills

- **Superpowers** (14 skills) - TDD, debugging, planning, code review workflows

## Prerequisites

- Node.js 18+
- [uv](https://github.com/astral-sh/uv) (for Serena MCP)
- Claude Code (`npm install -g @anthropic-ai/claude-code`)

## Manual Installation

If you prefer manual setup:

```bash
# Copy configs
cp settings.local.json ~/.claude/
cp commands/*.md ~/.claude/commands/
cp scripts/*.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/*.sh

# Install Superpowers
git clone https://github.com/obra/superpowers.git ~/.claude/skills/superpowers

# Add MCP servers
claude mcp add playwright -- npx @playwright/mcp@latest
claude mcp add serena -- uvx --from git+https://github.com/oraios/serena serena start-mcp-server --context claude-code
```

## Updating

```bash
cd ~/claude-dotfiles
git pull
./setup.sh
```
