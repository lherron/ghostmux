---
description: Create a new git worktree with a new branch in ~/praesidium/under-construction
argument-hint: <branch-name>
---

# /worktree

Create a new git worktree in the under-construction directory with a new branch.

## Usage

```
/worktree <branch-name>
```

## Workflow

1. **Check branch**: Check current branch is clean (no uncommitted changes). If not clean, run /commit to commit changes.

2. **Validate argument**: Ensure `$ARGUMENTS` is provided (the branch name)

3. **Create worktree**:
   ```bash
   git worktree add -b <branch-name> ~/praesidium/under-construction/<branch-name>
   ```

4. **Report**: Show the path to the new worktree and confirm creation

## Example

```
/worktree control-plane-feature-auth
```

Will:
- Check current branch is clean (no uncommitted changes) and commit if necessary
- Create new branch: `control-plane-feature-auth`
- Create worktree at: `~/praesidium/under-construction/control-plane-feature-auth`
