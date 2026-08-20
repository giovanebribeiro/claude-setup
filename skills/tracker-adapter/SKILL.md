---
name: tracker-adapter
description: Generic issue-tracker adapter contract (resolve project, create epic, create task, link parent-child, add comment) plus the approval-gate procedure — post created card keys/links and stop, never auto-continue into implementation. Currently backed by exactly one concrete adapter, Jira via the Atlassian MCP (see adapters/jira.md). Use when creating tracker cards for an approved plan.
agents: ["tracker-integrator"]
version: 1.0.0
---

# Tracker Adapter

Defines *what* tracker operations exist, independent of which tracker backs them. The
concrete "how" for each operation lives in `adapters/<name>.md`. Adding a second tracker
later means writing one more adapter file — this contract and `tracker-integrator.md`
don't change.

## Active adapter

Read `config.json`'s `active_adapter` field, then read `adapters/<active_adapter>.md` for
the concrete call sequence behind every operation below. Right now that's always `jira` —
`adapters/jira.md` is the only adapter implemented.

## Operations

| Operation | Purpose |
|---|---|
| `resolve_project(hint?)` | Resolve a project/board key. Never hardcode one — resolve from the hint, or ask/list options if none given. |
| `create_epic(project, fields)` | Create an epic-level issue with the org's charter template. |
| `create_task(project, parent?, fields)` | Create a task/story/bug-level issue, optionally linked under a parent epic. |
| `link_parent_child(parent, child)` | Attach an existing issue under a parent epic. |
| `add_comment(issue, body)` | Add a comment to an issue. |
| `transition_status(issue, target)` | Move an issue's status. **Declared for the seam, not implemented against Jira in this pass** — the create-card flow never calls it. Don't assume it works until an adapter documents it. |

## Never hardcode project/board

Always resolve the project/board key via `resolve_project`, or ask the user, rather than
assuming or defaulting one. Genericizing per-org values (custom field IDs, cloudId, board
filters) into this contract would be speculative complexity for a hypothetical
multi-tenant case that isn't needed — those live in
`~/.claude/agent-data/tracker/config.md` instead, read by the adapter at runtime.

## Approval gate

After `create_epic`/`create_task` calls succeed, the caller (`tracker-integrator`) reports
the created keys + links and **stops** — it never chains into code changes or further
tracker operations on its own. This rule lives here once so any future adapter inherits it
for free; don't re-derive or relax it per adapter.

## Example

Abstract call sequence for "create an epic with two linked tasks under project PROP":

```
resolve_project("PROP")              -> "PROP"
create_epic("PROP", {...})           -> "PROP-456"
create_task("PROP", parent="PROP-456", {...})  -> "PROP-457"
create_task("PROP", parent="PROP-456", {...})  -> "PROP-458"
```

See `adapters/jira.md`'s own Example section for the same sequence expressed as real
`mcp__atlassian__*` tool calls.

## Extending to a second tracker

To add e.g. Linear or GitHub Issues later: write `adapters/linear.md` implementing the
same operation table above, then set `active_adapter` to `"linear"` in `config.json`. No
changes needed to `tracker-integrator.md` or this file. **Do not build this now** — there
is no second tracker in use yet.
