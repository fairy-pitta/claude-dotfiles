# Global Rules

These rules apply to ALL sessions regardless of project.

## Language

- **Work projects** (forval-crossgear, etc.): Japanese for commits, comments, and communication
- **OSS projects** (python2ib, funcflow, etc.): English for commits, docs, and code comments
- Detect from repo context. If unclear, ask.

## Execution Style

- When executing a plan, **do not stop until all steps are complete**. Do not pause to ask for confirmation between steps unless blocked.
- Commit at logical milestones as you go (don't wait until the end).
- If context usage exceeds 80%, run `/compact` and continue.

## Commit Message Rules

Format: `type: concise description (50 chars max)`

Types: `feat` / `fix` / `refactor` / `test` / `docs` / `chore` / `style` / `perf`

**Prohibited (vague messages):**

- `fix: PRレビュー指摘を反映`
- `fix: レビュー対応`
- `chore: 修正`
- `fix: 諸々修正`

**Good examples:**

- `fix: UserRepositoryがPresentation DTOを返す依存方向を是正`
- `feat: 推移表AIアドバイスに月カラム選択UIを追加`

When changes span multiple themes, split into multiple commits by topic.

## Test Naming Convention

All test functions must follow: `test_<action>_<condition>_<expected_result>`

```python
# Good
def test_create_user_with_valid_email_returns_201() -> None: ...
def test_delete_user_without_permission_raises_403() -> None: ...

# Bad
def test_user_creation() -> None: ...
def test_it_works() -> None: ...
```

## Git Workflow

- **Never commit directly to main/master**
- Use feature branches: `feature/<name>`, `fix/<name>`, `refactor/<name>`
- Use worktrees for parallel development when appropriate
- Clean up worktrees after merging
- always check the branch you are commiting to. 

## Code Quality

- Always run tests before committing. If any fail, fix before commit.
- Run linters/formatters after edits (auto-format hook handles this).
- Add type hints to new code (Python: full type annotations, TypeScript: strict mode).

## Comments

- Delete comments that only make sense with external context the code reader doesn't have:
  - **Conversation context** — anything that only makes sense inside the AI-agent chat (e.g. `# 指摘により修正`, `# リクエスト通り`, `// as requested`, `// per review`).
  - **Implementation history** — comparisons with a previous version (e.g. `# 旧実装ではforループ`, `// changed from useState`, `# N+1を解消`).
  - **Context-less comments** — comments whose intent cannot be understood by reading the code alone (PR/diff/conversation-dependent notes).
- Keep comments that explain **why** the code is the way it is for a future reader. The rule removes change-narration, not genuine intent documentation.
