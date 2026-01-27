---
name: triage-shaping
description: Shape and refine a wrkq task by ID. Use when given a task ID to analyze, clarify requirements, and automatically update the task with a structured implementation approach and recommendations.
---

# Triage Shaping

Shape an existing wrkq task into a well-defined, actionable specification.

## Usage

```
/triage-shaping <wrkq cat task> OR <task-id> <task-slug>
```

## Process

### Step 1: Fetch Task Details and mark as in_progress

**if** the full task was not provided, read the task by ID:

```bash
wrkq cat <task-id>
wrkq set <task-id> --state in_progress
```

### Step 2: Understand the Ask

Before shaping:
1. Read the task description thoroughly
2. Explore any referenced files or code
3. Understand the scope and constraints
4. Identify what's ambiguous or underspecified

### Step 3: Context Grounding (Environment Scan)

Orient to the environment:
- Scan for existing patterns that inform reasonable defaults
- Note what's present that the proposal should integrate with
- Identify constraints the user may not have stated but likely expects

### Step 4: Shape the Implementation

Apply prompt-shaping techniques:

1. **Restate in natural language** - Articulate what you understand the task wants, making assumptions explicit
2. **Bullet the structure** - Break the restatement into scannable components
3. **Propose an iterative grounding loop** - Define how to verify the work is complete
4. **Document recommendations** - Note any ambiguities with recommended approaches

### Step 5: Grounding Loop (Iterative Testing)

Propose how completion will be verified:
- **Define success criteria** - What observable outcome proves the request is fulfilled?
- **Propose a verification method** - A concrete check (test, command, assertion)
- **Commit to iteration** - Run verification until it passes

Use fully integrated tests, not mocks.

### Step 6: Update Task in wrkq

Automatically update the task with the shaped specification. Include in the updated task:

- Original task summary
- Shaped interpretation with explicit assumptions
- Structured breakdown of work
- Success criteria and grounding loop
- Recommendations for any ambiguities

Then:

1. **Update the task description** with the shaped specification:
```bash
wrkq edit <task-id>
```

2. **Mark the task as open** (ready for execution):
```bash
wrkq set <task-id> --state open
```

3. **Add a comment** documenting the shaping and recommendations:
```bash
wrkq comment <task-id> "Shaped implementation approach - ready for execution. Recommendations: [list any assumptions or recommendations]"
```

## Example

```
User: /triage-shaping T-00042

Claude: Let me fetch and analyze this task...

[Runs: wrkq cat T-00042]

**T-00042: Add user preferences API**
- Priority: 2
- State: draft
- Description: "Need some way to save user preferences"

This task is underspecified. Let me shape it:

---

**Shaped Interpretation:**

It sounds like you want to persist user-configurable settings. I'm assuming:
- REST API endpoints (GET/PUT /api/preferences)
- JSON storage per user
- Schema includes: theme, notifications, locale
- Authenticated users only

**Structured Breakdown:**
1. Define preferences schema/types
2. Add database migration for preferences table
3. Implement GET endpoint (fetch current)
4. Implement PUT endpoint (update)
5. Add validation middleware

**Grounding Loop (Iterative Testing):**
I'll write integration tests for both endpoints, iterating until they pass with valid auth and reject without.  I will not use mocks.

**Recommendations:**
- Consider whether preferences should sync across devices (not specified, defaulting to per-device storage)
- Default schema includes theme, notifications, locale; can be extended if needed

---

[Runs: wrkq edit T-00042, wrkq set T-00042 --state open, wrkq comment T-00042]

Updated T-00042 with shaped specification and marked as open.
```

## Notes

- This skill shapes tasks but does NOT execute them
- The goal is to transform vague requests into actionable specifications
- Always surface assumptions explicitly in the task comment
- Automatically updates the task with the shaped specification and recommendations
