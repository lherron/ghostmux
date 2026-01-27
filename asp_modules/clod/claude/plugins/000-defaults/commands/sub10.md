---
description: Run input in parallel with 10 sonnet subagents
allowed-tools: Task
---

Run the following task in parallel using up to 10 sonnet subagents. Direct each agent to work on whichever aspects or subtasks will best accomplish the overall goal. Determine the appropriate number of agents based on task complexity and parallelizability. Use the Task tool with `model: "sonnet"` for each agent. Launch all agents in a single message with multiple Task tool calls to maximize parallelism.

Task to run with each subagent:
$ARGUMENTS
