---
name: jira-project-health
description: Project-planning & execution health report for a Jira project's In-Progress Epics — a macro view (each Epic's objective↔cards coverage, progress tally, schedule health, characteristics sanity, and strategy drift) plus a micro view (recent comments on the cards within those Epics, verbatim). Use when the user wants feedback on how well projects are being planned and executed, an Epic-level status/health report, or to monitor a board like TEAM or ACME.
agents: ["pm-assistant"]
---

# Jira Project Health

Builds an Epic-level health report for one Jira project: a **macro view**
(how well each In-Progress Epic matches its objective, due date, and
characteristics versus the cards actually planned and executed inside it) and a
**micro view** (recent comments on those cards, showing team-work detail).
Output is a markdown report file; email/Confluence delivery is opt-in.

**Requires the Atlassian (Jira) MCP server connected** (server endpoint: https://mcp.atlassian.com/v1/mcp/authv2) — every step calls
`mcp__atlassian__*` tools. Do not scrape Jira via WebFetch as a substitute.

**If `mcp__atlassian__*` tools aren't available**, the Atlassian MCP isn't
connected. Tell the user to run `/mcp`, add/select the **Atlassian** connector,
complete the OAuth login, confirm `/mcp` shows "Connected to atlassian", then
retry.

**If the MCP is listed as connected but tools fail** (auth errors, empty
results, "not authorized", or calls that hang) — the session/token likely went
stale. Tell the user to **re-authenticate or re-enable** the connector: run
`/mcp`, select **Atlassian**, and re-run its login (or toggle the server off
and on), then retry the skill. A silent re-auth in `/mcp` usually clears it
without any other change.

## Inputs

- **Project key** (required): e.g. `TEAM`, `ACME`. This is the JQL
  project key, *not* a board ID. If unknown/ambiguous, list with
  `mcp__atlassian__getVisibleJiraProjects` and confirm.
- **Window days** (optional, default **7**): look-back for "recent" comments in
  the micro view. The user may override per call ("…over the last 14 days").

## Core model (read this first)

- **Macro unit = Epic.** Each In-Progress Epic is one "project" in the report.
- **In-Progress = native `statusCategory`**, filtered in JQL by the
  English key `statusCategory = "In Progress"` (language-agnostic). Display
  names are localized (e.g. PT "Em andamento"; the To-Do bucket may be
  called something like "Itens Pendentes") — never filter on display
  strings.
- **Never trust the custom "Epic Status" field.** On at least one client's
  instance it reads `"To Do"` on every Epic regardless of real progress
  (dead legacy field) — check the client's `CONTEXT.md` for whether this
  applies here. Report it only as a data-hygiene alert, never as status.
- **Cards within an Epic** — the linkage types vary per client's Jira setup;
  check `<client_root>/CONTEXT.md` for this client's actual model (e.g. one
  observed client uses the union of hierarchy children `parent = <EPIC>` and
  an "Iniciativa" issue-link relation, link type id `10109`).

## Workflow

### 0. Resolve the client
Invoke the `client-context` skill's `resolve_client_root()` to find
`<client_root>` (walk-up from cwd, or ask if that fails). Read
`<client_root>/CONTEXT.md`, `EPIC-STANDARDS.md`, and `VOCABULARY.md` for this
client's Jira model, conventions, and roster — needed throughout the steps
below and for judging what "well-defined" means at the end.

### 1. cloudId (once per session, cache it)
Try `cloud_id` from `<client_root>/TRACKER.md` first. If absent, or the call
fails with an auth/resource error, call
`mcp__atlassian__getAccessibleAtlassianResources`; take the `id` (UUID)
and `url` (hostname for browse links, e.g. `acme.atlassian.net`) of the
Jira-scoped resource, and update `TRACKER.md` with the corrected value.

### 2. Find In-Progress Epics
```
mcp__atlassian__searchJiraIssuesUsingJql
  cloudId: <id>
  jql: 'project = <KEY> AND issuetype = Epic AND statusCategory = "In Progress" ORDER BY updated DESC'
  fields: ["*all"]
  maxResults: 100
  responseContentFormat: markdown
```
With `fields: ["*all"]` this call almost always exceeds the inline token limit
and is **saved to a file** (path in the result). Don't `Read` it — use `jq`.
**The JSON shape depends on whether the result was returned inline or saved:**
- **inline** (small result): `{issues: [ {key, fields, ...} ], isLast}` — array
  directly under `.issues`.
- **saved to file** (large result): `{issues: {nodes: [ {key, fields, names} ]}}`
  — array under `.issues.nodes`, with a per-node `.names` map of
  `customfield_* → display name` (only when `expand: names` was used).

Always probe first (`jq 'keys'`, then `jq '.issues|keys'` or
`jq '.issues|type'`) before extracting. **Practical tip:** to *list* the Epics
use a minimal explicit `fields` list (summary, status, duedate, created,
updated, assignee, description) — that usually returns inline and stays
jq-able, avoiding the giant `*all` dump entirely.

### 3. Per Epic: discover characteristics (dynamic field discovery)
The meaningful custom-field set differs per project, and the org has a large
noise sprawl. Get the field-name map once via a single
`mcp__atlassian__getJiraIssue` with `expand: names`, `fields: ["*all"]` on any
one Epic (saved to file; `jq '.issues.nodes[0].names'` → the global
`customfield_* → name` map, reusable for all Epics since custom-field ids are
instance-global).

**Efficient path (proven):** the `*all` payload is too big to read directly.
Instead — (1) get the global `names` map once (`jq '.issues.nodes[0].names'`
from one saved `getJiraIssue` `*all` file; ~3000+ entries); (2) grep it for the
meaningful field display names (check `<client_root>/VOCABULARY.md`'s custom
fields table for known ones on this project first) to get their
`customfield_*` ids; (3) re-query all Epics with an **explicit list of just
those ids** → small, jq-able JSON. Render mixed value types with a helper:
`def v: if .==null then "—" elif type=="object" then (.value//.name//.displayName)
elif type=="array" then (map(if type=="object" then .value else . end)|join(", "))
else tostring end;`

Then **keep a custom field only if ALL hold** (the noise filter):
- value is non-null / non-empty (`!= null, "", [], {}`),
- the field has a real display name (not blank/whitespace),
- rendered value is a **short scalar** — option `.value`/`.name`, date, user
  `.displayName`, or small string/array, **under ~200 chars**,
- value contains **no markup tokens**: `{panel`, `{color`, `h3.`, `||`,
  table/ADF syntax,
- field name is **not** in the denylist: `Epic Status`, `Epic Color`,
  `Issue color`, `Rank`, `Checklist*`, `Development`, and `Info*` / `Aviso*` /
  `Mensagem*` template fields.

Also pull the native `summary`, `description` (objective text), `duedate`,
`status.name`, `created`, `updated`, `assignee`.

Example extraction (adapt paths to the saved file):
```bash
jq -r --slurpfile nm /tmp/names.json '
  $nm[0] as $n |
  .issues.nodes[] | {key, summary:.fields.summary,
    status:.fields.status.name, due:.fields.duedate} ' <epics-file>
```

### 4. Per Epic: collect the cards within it
Per the linkage model resolved in Step 0 (e.g. for a client using the union
model): two JQL searches (union, dedup by key):
```
project = <KEY> AND parent = <EPIC>
issue in linkedIssues("<EPIC>", "Iniciativa Filha")
```
For each card pull `summary, status, statusCategory, duedate, assignee,
resolution, resolutiondate, issuetype, project`. Note cards whose `project`
differs from `<KEY>` (cross-project mixing — an alert).

### 5. Recent comments (micro view) on those cards
Restrict to the Epic's cards (not the whole project). For cards updated in the
window:
```
key in (<card keys>) AND updated >= -<N>d
fields: ["summary","assignee","comment","parent"]
```
Large output → saved to file → `jq`. Filter comments to those `created` within
the window; keep author `displayName`, `created`, body (markdown as-is, don't
re-render). Group by Epic, then by card.

### 6. Analyse — the five macro dimensions, per Epic
1. **Objective ↔ cards coverage** — does the executed/planned card set cover
   the stated objective (native description, plus any client-specific
   objective-text field — check `VOCABULARY.md`; one observed client calls
   theirs "Breve descrição")? Flag parts of the objective with no dedicated
   card (a *gap*).
2. **Progress tally** — counts of cards done / in-progress / pending/to-do.
3. **Schedule health** — Epic `duedate` present? overdue vs today? cards
   with/without due dates? **stagnation** (no card or comment activity in the
   window)?
4. **Characteristics sanity** — the discovered custom fields, with
   contradictions flagged (e.g. stale "Epic Status", a review/approval field
   stuck in a blocking state, missing native description — one observed
   client's example: SecOps field stuck on "Em Análise").
5. **Strategy drift** — cards whose subject matter diverges from the Epic
   objective. Drift = *extra* off-objective cards being absorbed (sign of
   stakeholder requests landing mid-sprint without strategic connection), as
   distinct from a coverage gap (*missing* cards). Cite specific card keys and,
   where relevant, recent comments as evidence.

Comments from step 5 are **evidence the analysis cites** (a blocker in a
comment → schedule-health alert; off-objective chatter → drift evidence) **and**
are reproduced verbatim in the micro section.

### 7. Output
Write a markdown file under **`<client_root>/_reports/`** (create the dir if
missing): `<client_root>/_reports/epic-health-<KEY>-<YYYY-MM-DD>.md`. The filename
pattern is fixed/language-neutral regardless of the report's own language (below).

**Hyperlink every Epic and card key.** Build browse links from the `url`
hostname captured in step 1: `https://<host>/browse/<KEY>` (e.g.
`https://acme.atlassian.net/browse/POINT-123`). Render each key as a
markdown link `[<KEY>](https://<host>/browse/<KEY>)` everywhere a key appears —
Epic headings, the Cards table, comment lines, and any key cited in the
analysis/alerts section. Never print a bare key.

**Render using `<client_root>/TRACKER.md`'s "Epic health report skeleton"** (under
"Report skeletons"), if that client has filled one in — language, section names, and
field labels are their convention, not a Jira requirement. Map this skill's internal
neutral categories (see step 6) to their status label mapping table at render time.
If the client hasn't defined a skeleton, use this generic default:

```
# Epic Health Report — <KEY>
Project: <KEY> — <project name>
Report date: <YYYY-MM-DD> · Comment window: last <N> days

## [<EPIC-KEY>](https://<host>/browse/<EPIC-KEY>) — "<summary>"
**Objective:** <description — check VOCABULARY.md for this client's objective-text
field if it's not the native description>

| Field | Value |   ← discovered characteristics (filtered)
...

### Linked cards
| Card | Summary | Status | Due date | Assignee |  ← note linkage type if useful
| [<CARD-KEY>](https://<host>/browse/<CARD-KEY>) | ... |

### Progress vs. objective
<narrative covering coverage, tally, schedule, characteristics, drift —
cite card keys as links too>

### Recent comments
- [<card>](https://<host>/browse/<card>) · <author> | <timestamp> — <body>

## Alerts & gaps   ← consolidated across all Epics
1. ...
```
Then echo a short summary in chat (Epic count, headline alerts).

See `<client_root>/EPIC-STANDARDS.md` and `VOCABULARY.md` for the
company-specific conventions a "well-defined" Epic/card is judged against.

### 8. Optional delivery (only if the user asks)
- **Email**: needs the Gmail MCP authenticated (`mcp__claude_ai_Gmail__*`).
  If only the `authenticate` tool is exposed, the user must complete its OAuth
  first. Don't block the report on this.
- **Confluence**: `mcp__atlassian__createConfluencePage` (contentFormat html).

## Notes
- Default comment window is 7 days; user-overridable.
- Run once per project (separate report files for each project key, e.g. TEAM, ACME).
- Localized statuses: filter via the English JQL key, read display names as-is.
- If a `searchJiraIssuesUsingJql`/`getJiraIssue` result is saved to a file,
  probe with `jq 'keys'` / `.issues.nodes[0]|keys` before extracting — the
  saved schema is `{issues:{nodes:[...]}}`, and `.[0].text` deprecation
  notices may precede data in some tool shapes.
