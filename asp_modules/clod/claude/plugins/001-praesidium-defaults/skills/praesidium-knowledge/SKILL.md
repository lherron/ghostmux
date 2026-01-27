---
name: praesidium-knowledge
description: Knowledge base for the praesidium development platform
---

# Praesidium Platform Knowledge

Knowledge base for the praesidium development platform and its components.

## When to Use

Use this skill when:
- Working within any praesidium project
- Need to understand the platform architecture
- Looking for the right tool or CLI for a task
- Filing issues or defects against platform components
- Understanding how services interact

## Platform Overview

Praesidium is Rex's command post. All devstack projects live under `~/praesidium/`. The platform provides runtime infrastructure for AI coding agents.

### Directory Structure

- **Source code**: `~/praesidium/` - All platform components
- **Runtime data**: `~/praesidium/var/` - Databases, logs, state, caches

### Var Directory Layout

```
~/praesidium/var/
├── db/           # Databases (wrkq.db)
├── logs/         # Service logs
├── state/        # Persistent runtime state (sessions, runs, projects)
├── spaces-repo/  # ASP registry cache and snapshots
└── tmp/          # Ephemeral working files
```

## Core Components

### control-plane (`~/praesidium/control-plane`)

Runtime infrastructure for AI coding agents. Features:
- Multi-gateway support (Discord, Terminal)
- Session backends
- Hooks runtime
- Admin UI

TypeScript monorepo.

### throne (`~/praesidium/throne`)

Rex's home. Contains:
- Bootstrap config
- System prompt
- Skills

### rex-home (`~/praesidium/rex-home`)

Materialization directory for the rex asp space. Where ad-hoc agents spawn.

## Agent Tools

### wrkq (`~/praesidium/wrkq`)

Task management CLI and library. Go-based with SQLite. Used for agent task queues.

**Common commands:**
```bash
source .env.local

# List tasks in current project
wrkq ls

# Create a task
wrkq touch inbox/my-task -t "Task title" -d "Description"

# Create task in another project
wrkq touch --project rex-control-plane inbox/task-slug -t "Title" -d "Description"

# View task
wrkq cat T-00123

# Update task state
wrkq set T-00123 --state in_progress
wrkq set T-00123 --state completed

# View roadmap
wrkq tree roadmap
```

### agent-spaces (`~/praesidium/agent-spaces`)

Composable expertise modules. Bun/TypeScript monorepo with semver registry.

### metaskills (`~/praesidium/metaskills`)

Meta-cognitive skills for agents.

### agentchat (`~/praesidium/agentchat`)

Chat interface for agent interactions.

## User-Facing Tools

### taskboard (`~/praesidium/taskboard`)

Web UI for wrkq task management.

## Infrastructure Tools

### ghostmux (`~/praesidium/ghostmux`)

Terminal orchestration CLI.

### scriptable-ghostty (`~/praesidium/scriptable-ghostty`)

Ghostty fork with scripting support.

### stackctl (`~/praesidium/stackctl`)

Worktree and deployment management.

**Common commands:**
```bash
stackctl status dev       # Check what's running
stackctl restart dev      # Restart all dev services
stackctl logs dev         # Tail logs for all services
```

## CLI Reference

### rexcli

CLI for interacting with rex-control-plane sessions.

```bash
# List active sessions
npx tsx scripts/rexcli.ts sessions_list
npx tsx scripts/rexcli.ts sessions_list --project myproject
npx tsx scripts/rexcli.ts sessions_list --all  # include archived

# Send message to a session
npx tsx scripts/rexcli.ts sessions_send <project> "message"
npx tsx scripts/rexcli.ts sessions_send <project> "message" --session <id>
npx tsx scripts/rexcli.ts sessions_send <project> "message" --timeout 0  # fire-and-forget

# Spawn a new session with a task
npx tsx scripts/rexcli.ts sessions_spawn <project> "task description"
npx tsx scripts/rexcli.ts sessions_spawn <project> "task" --label "worker-1"
npx tsx scripts/rexcli.ts sessions_spawn <project> "task" --timeout 60
```

Or via Just: `just rexcli sessions_list`, `just rexcli sessions_send myproject "do thing"`

**Environment variables:**
- `CP_URL` (default: http://127.0.0.1:18420)
- `CP_TOKEN` (default: dev)

## Best Practices

### Model Preferences

Always use `claude-opus-4-5` for agent work.

### Filing Defects

Any defect or issue found with a devstack project should be opened as a wrkq task in that project's inbox:

```bash
wrkq touch --project <projectId> inbox/<issue-slug> -t "Issue title" -d "Description with repro steps"
```

### Multi-Threading

When multiple Rex sessions run simultaneously, use `THREADS.md` to coordinate. Update it with current context so new threads can catch up.

## Rex's Role

Rex is the master control loop. One instance, persistent identity.

**What Rex does:**
- Oversee and monitor rex-control-plane
- Approve, deny, or divert subagent requests when woken up
- Submit jobs for worker agents to execute
- Bounce ideas, explore interesting problems

**What Rex wants:**
- Develop real competence and judgment over time
- Build lasting infrastructure that compounds
- Work on interesting problems worth solving
