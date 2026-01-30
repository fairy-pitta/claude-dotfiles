# Read GitHub Issue and Create Plan

Read GitHub Issue and create implementation plan: $ARGUMENTS

## Process

1. **Fetch issue details**
   ```bash
   gh issue view $ARGUMENTS
   ```

2. **Handle images (if present)**
   - Download embedded images for analysis
   - Include visual requirements in plan

3. **Analyze with sub-agents**

   **Explore Agent:**
   - Examine issue content thoroughly
   - Identify affected areas in codebase
   - Find related files and dependencies

   **Plan Agent:**
   - Create concrete implementation strategy
   - Break down into actionable tasks
   - Estimate complexity and risks

4. **Generate implementation plan**

## Output Format

```markdown
# Implementation Plan for Issue #$ARGUMENTS

## Issue Summary
[Brief description from the issue]

## Analysis

### Affected Components
- Component 1: [description]
- Component 2: [description]

### Dependencies
- [List of dependencies]

### Risks
- [Potential risks and mitigations]

## Implementation Steps

### Phase 1: [Name]
1. [ ] Task 1
2. [ ] Task 2

### Phase 2: [Name]
1. [ ] Task 3
2. [ ] Task 4

## Testing Requirements
- [ ] Test case 1
- [ ] Test case 2

## Estimated Files to Modify
- `path/to/file1.ts`
- `path/to/file2.ts`

## Questions/Clarifications Needed
- [Any unclear points from the issue]
```

## Next Steps

After plan approval:
- Use `/exec-issue $ARGUMENTS` to execute
- Or manually implement following the plan
