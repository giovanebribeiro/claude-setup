---
name: jira-executive-summary
description: Director-facing executive summary across one or more Jira boards/projects — opportunities, emerging failure points, and recommended anticipatory action (re-prioritize, split an Epic, etc). Consumes jira-project-health reports rather than querying Jira directly. Use when the user wants a status update "for my Director," a cross-board picture, or asks to summarize/condense existing health reports.
agents: ["pm-assistant"]
---

# Jira Executive Summary

Reframes one or more `jira-project-health` reports into a short, strategic
document for someone who does not need per-card detail — only what's working,
what's at risk, and what decision they might need to make.

**Does not call Jira directly.** It reads `jira-project-health` report
files (`<client_root>/_reports/epic-health-<KEY>-<YYYY-MM-DD>.md`). If the needed
report(s) don't exist yet or are stale (older than the user's window), run
`jira-project-health` first for each project key in scope, then come back to
this skill.

## Workflow

### 0. Resolve the client
Invoke the `client-context` skill's `resolve_client_root()` to find
`<client_root>` (walk-up from cwd, or ask if that fails). Reports are read
from and written to `<client_root>/_reports/`.

## Inputs

- **Project keys** (required, one or more): e.g. `TEAM`, `ACME`. Ask if not
  stated — never assume "all boards."
- **Audience framing** (optional): default is a generic Director; the user
  may ask for a different framing (e.g. "for the CTO").

### 1. Gather source reports
For each project key, find the most recent
`<client_root>/_reports/epic-health-<KEY>-*.md`.
If missing or the user says it's stale, tell them which project needs a fresh
`jira-project-health` run before you can continue — don't fabricate findings
from memory.

### 2. Extract signal, drop noise
From each report's macro view and its alerts/gaps footer section (rendered
per this client's skeleton, e.g. "Alertas e lacunas" for one observed
client), pull out only what matters at Director altitude:
- **Opportunities** — Epics ahead of schedule, well-scoped wins worth
  highlighting or doubling down on.
- **Emerging failure points** — overdue Epics, strategy drift, undocumented
  work, coverage gaps — but only the ones with real consequence (a card
  missing a due date is noise; an Epic with no activity in 3 weeks and an
  unaddressed blocker comment is signal).
- **Recommended anticipatory action** — for each failure point, a concrete
  next move: re-prioritize, split the Epic, reassign, escalate a blocker,
  or explicitly "no action needed yet, monitoring."

Do not just summarize the health report shorter — translate from
"is this Epic well-defined" language to "should we change course" language.

### 3. Output
Write a markdown file under `<client_root>/_reports/`:
`<client_root>/_reports/exec-summary-<YYYY-MM-DD>.md`. The filename pattern is
fixed/language-neutral regardless of the report's own language (below).

**Render using `<client_root>/TRACKER.md`'s "Executive summary skeleton"**
(under "Report skeletons"), if that client has filled one in. If not, use
this generic default:

```
# Executive Summary — <date>
Projects covered: <KEY1>, <KEY2>...

## Opportunities
- <Epic/board> — <why it's an opportunity, 1-2 sentences>

## Points of concern (emerging risks)
- <Epic/board> — <what's wrong> — **Recommended action:** <concrete action>

## No action needed
- <Epic/board> — monitored, no risk signal
```

Hyperlink Epic/card keys the same way the source health report does. Then
echo a 3-5 line summary in chat.

### 4. Optional delivery (only if the user asks)
Same as `jira-project-health` — Gmail MCP for email, `createConfluencePage`
for Confluence.
