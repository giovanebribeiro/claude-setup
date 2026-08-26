---
name: client-context
description: Resolves which client's shared context folder (VOCABULARY.md, CONTEXT-MAP.md, EPIC-STANDARDS.md, TRACKER.md under ~/workspace/<client>/) an operation should read, for tools that work across multiple clients rather than being locked to one. Use before reading any client-specific vocabulary, epic/card standards, or tracker connection details.
agents: ["pm-assistant", "tracker-integrator"]
version: 1.0.0
---

# Client Context Resolver

Multiple clients live side by side under `~/workspace/`, each with its own
`VOCABULARY.md`, `CONTEXT-MAP.md`, `EPIC-STANDARDS.md`, and `TRACKER.md` at the root of
`~/workspace/<client_name>/`. A tool that works with more than one client (`pm-assistant`,
`tracker-integrator`) must resolve which client's files apply to the current operation
instead of hardcoding a path — that hardcoding is exactly what made these tools
single-client before this skill existed.

## Marker files

A directory is a **client root** if it directly contains all four:

- `VOCABULARY.md`
- `CONTEXT-MAP.md`
- `EPIC-STANDARDS.md`
- `TRACKER.md`

All four, not a subset — a project folder that happens to have its own `CONTEXT.md` (a
different filename) doesn't count.

## `resolve_client_root()`

Two tiers, in order:

### 1. Walk up from the current working directory

Starting at cwd, check each directory against the marker-file test above, then move to
its parent, stopping once you reach `~/workspace` (inclusive — check it too, then stop;
never walk above it). If a match is found, that's the client root — use it directly, no
need to ask.

This covers the common case: the tool was invoked while working inside a client's
project folder (e.g. `~/workspace/acme/acme-webapp/`), which is nested under that
client's root.

### 2. Ask, don't guess

If the walk-up finds nothing — this happens whenever the invoking tool itself lives
outside every client folder (e.g. `~/workspace/pmo`, which is deliberately a sibling of
client folders, not nested inside one, so it can serve more than one client) — do NOT
default to any particular client, even if only one exists today. List candidates by
scanning immediate subdirectories of `~/workspace/` for the marker-file set, then ask
the user which client this operation is for. If exactly one candidate exists, still
confirm rather than silently assuming — a second client folder may be created later and
a hardcoded assumption is exactly the bug this skill exists to avoid.

## What callers do with the resolved root

Once `<client_root>` is known:

- Read `<client_root>/VOCABULARY.md` for people/roles/boards/tools recognition.
- Read `<client_root>/EPIC-STANDARDS.md` for card/epic authoring conventions.
- Read `<client_root>/TRACKER.md` for tracker connection details (site, project keys,
  custom-field IDs, description template) — this supersedes the old host-global
  `~/.claude/agent-data/tracker/config.md` pattern.
- Read `<client_root>/CONTEXT-MAP.md` to see what else exists for this client
  (project folders, other tools) before assuming nothing else is relevant.

## Example

`tracker-integrator` invoked while cwd is `~/workspace/acme/acme-webapp/apps/web`:

```
resolve_client_root()
  check ~/workspace/acme/acme-webapp/apps/web  -> no marker files
  check ~/workspace/acme/acme-webapp            -> no marker files
  check ~/workspace/acme                         -> all four present -> MATCH
-> ~/workspace/acme
```

`pm-assistant` invoked while cwd is `~/workspace/pmo`:

```
resolve_client_root()
  check ~/workspace/pmo       -> no marker files
  check ~/workspace           -> no marker files (this is the stopping point)
  no match -> list subdirectories of ~/workspace/ with all four marker files
           -> found: acme
  ask user: "This looks like it's for a specific client's Jira — which one? (acme)"
```
