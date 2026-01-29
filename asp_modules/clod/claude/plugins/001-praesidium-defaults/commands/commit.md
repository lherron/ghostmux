---
description: Create a git commit with staged changes and push to remote
---

# /commit

Create a well-formatted git commit for the current changes and push them to the remote repository.

## Workflow

1. **Gather context** (run in parallel):
   - `git status` to see all untracked and modified files (never use `-uall` flag)
   - `git diff` to see unstaged changes
   - `git diff --cached` to see staged changes
   - `git log --oneline -5` to see recent commit message style

2. **Analyze changes**:
   - Review all staged and unstaged changes
   - Identify the nature: new feature, enhancement, bug fix, refactor, test, docs, etc.
   - Check for files that should NOT be committed (`.env`, credentials, secrets)

3. **Stage files**

4. **Create commit**:
   - Draft a concise message (1-2 sentences) focusing on "why" not "what"
   - Use conventional commit prefixes when appropriate: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
   - Do not include Co-Authored-By line

5. **Verify**: Run `git status` after commit to confirm success

6. **Push commit**

## Commit Message Format

Always use HEREDOC to ensure proper formatting:

```bash
git commit -m "$(cat <<'EOF'
feat: add user authentication flow

Implements login/logout with session management.
EOF
)"
```

## Agent Rules

- **NEVER** skip hooks (`--no-verify`) unless explicitly requested
- **NEVER** commit files that likely contain secrets, ask the user
- **IMPORTANT**: Any lint/typecheck/test failures are YOUR responsibility to fix, do not bypass checks or ask the user to fix them.
