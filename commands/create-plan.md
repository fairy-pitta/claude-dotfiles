# Create Implementation Plan

Create an implementation plan and GitHub Issue for: $ARGUMENTS

## Process

1. **Prepare repository**
   ```bash
   git checkout main
   git pull origin main
   ```

2. **Analyze the task**
   - Use Explore sub-agent to understand codebase structure
   - Use Plan sub-agent to design implementation approach
   - Identify affected files and components
   - Consider dependencies and risks

3. **Create detailed plan**
   Structure:
   - Overview / Summary
   - Requirements list
   - Implementation phases (with checkboxes)
   - Affected files
   - Testing strategy
   - Pre-implementation confirmations

4. **Create GitHub Issue**
   ```bash
   gh issue create --title "[Title]" --body "[Plan content]"
   ```

5. **Iterate with feedback**
   - Present plan to user
   - Gather feedback
   - Refine until approved

## Output

- Finalized implementation plan
- Created GitHub Issue with number
- Ready for execution

## Template

```markdown
## Overview
[Brief description of the task]

## Requirements
- [ ] Requirement 1
- [ ] Requirement 2

## Implementation Phases

### Phase 1: [Name]
- [ ] Task 1.1
- [ ] Task 1.2

### Phase 2: [Name]
- [ ] Task 2.1

## Affected Files
- `path/to/file1.ts`
- `path/to/file2.ts`

## Testing Strategy
- [ ] Unit tests
- [ ] Integration tests
- [ ] Manual verification

## Pre-implementation Confirmations
- [ ] Dependencies identified
- [ ] Breaking changes assessed
- [ ] Stakeholder approval
```
