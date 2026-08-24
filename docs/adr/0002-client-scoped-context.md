# Company-specific context moved out to per-client workspace folders

Supersedes the second paragraph of
[0001](./0001-board-agnostic-skills.md), which deliberately kept Trillia
quirks hardcoded/at a repo root on the grounds that a second client was
"a hypothetical multi-tenant use case that isn't needed yet."

That stopped being true: this tooling is now used against more than one
client's Jira. Keeping `VOCABULARY.md`/`EPIC-STANDARDS.md`/`CONTEXT.md` at a
repo root meant a second client's data would either overwrite the first's or
force a fork of the tool just to swap out vocabulary — neither is acceptable
for tooling explicitly designed to be reusable (see 0001's first paragraph,
which still holds).

## Decision (original scope)

- Company-specific context (`VOCABULARY.md`, `EPIC-STANDARDS.md`) and tracker
  connection details (`TRACKER.md`) move to `~/workspace/<client>/` — one
  folder per client, sitting outside any tool's repo entirely. A
  `CONTEXT-MAP.md` in that folder indexes them plus the client's project
  folders.
- A new skill, `client-context` (`~/.claude/skills/client-context/`), defines
  how any tool resolves *which* client's folder applies to the current
  operation: walk up from the working directory looking for a folder
  containing the marker files, falling back to asking the user if nothing is
  found. Never defaults to a specific client, even when only one exists.
- `tracker-integrator`/`tracker-adapter` invoke this skill instead of reading
  a fixed path.
- Blank templates for onboarding a new client live at
  `~/workspace/_templates/client/`.

## Amendment — `pm-assistant`/`jira-*` promoted out of `pmo`, `CONTEXT.md` joins the client folder

The original pass above still left `pm-assistant` and the `jira-*` skills
living inside the `pmo` repo's `.claude/` — project-scoped, so they only
loaded when Claude Code was opened inside `pmo`. That's the same coupling
problem this ADR already solved for `VOCABULARY.md`/`EPIC-STANDARDS.md`, just
one layer up: the *tool* itself, not just its data, was locked to one repo.

Follow-up decision:

- `pm-assistant` and all `jira-*` skills are promoted to
  `~/.claude/agents/`/`~/.claude/skills/` — global, available regardless of
  working directory, same as `tracker-integrator`/`tracker-adapter` already
  were.
- `CONTEXT.md` (generic-looking Jira glossary) turned out not to be
  client-agnostic on inspection — it documents this client's actual linkage
  type ids, custom field names, and localized status strings, which are
  Jira-instance-specific, not universal. It moves into the client folder
  alongside the other three files, read by `pm-assistant` from
  `<client_root>/CONTEXT.md`.
- Report output (`jira-project-health`, `jira-executive-summary`,
  `jira-sprint-retro`) moves from a bare `reports/` path (implicitly
  cwd-relative, only correct when cwd happened to be `pmo`'s root) to
  `<client_root>/_reports/` — scoped to the client the report is about,
  regardless of where the skill was invoked from.
- `jira-create-card` had a literal hardcoded cloudId in its body (a real
  violation of the "never hardcode" principle from 0001, found while doing
  this pass) — fixed to resolve `cloud_id` from `<client_root>/TRACKER.md`
  first, matching `tracker-adapter`'s Jira adapter.
- `pmo` keeps only what's genuinely reusable-tool-but-not-client-data:
  nothing, in this case — once `CONTEXT.md` and the agent/skills leave, `pmo`
  is left holding just `apps/team-allocation-graph/`, an unrelated standalone
  app that happens to live in the same repo.

## Consequences

- Cloning `pmo` (or any repo) is no longer a prerequisite for using
  `pm-assistant` against a client's Jira — the tool is global, only the data
  is per-client.
- Any tool reading `VOCABULARY.md`/`EPIC-STANDARDS.md`/`TRACKER.md`/
  `CONTEXT.md` must resolve the client root first — a hardcoded relative path
  to a repo root is a bug, not a shortcut.
- The host-global `~/.claude/agent-data/tracker/config.md`/`vocabulary.md`
  (single-instance, gitignored) that `tracker-integrator` used before the
  original pass of this decision is retired — its content was migrated into
  the relevant client's `TRACKER.md`/`VOCABULARY.md`.
