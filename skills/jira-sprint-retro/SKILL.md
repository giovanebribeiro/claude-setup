---
name: jira-sprint-retro
description: Biweekly executive sprint retrospective for a Jira board — per-Epic lists of cards finished or in progress (with owner and any comment-trail updates), where each project is headed next, and blockers/constructive feedback (Bloqueios e alertas). Built for showing a Director/exec a "last sprint" overview. Use when the user wants a sprint retrospective, biweekly status for a Director/exec, or a per-Epic progress report on a board like TEAM or ACME.
agents: ["pm-assistant"]
---

# Jira Sprint Retro

Builds a biweekly, exec-facing retrospective for one Jira project: per
In-Progress Epic, the cards **Finalizado** and **Em andamento / Revisão**
in the window — each a bullet with its owner and, when the card's comment
trail has a substantive update, that update folded inline — where the Epic
is headed next ("Onde estamos indo"), and a **Bloqueios e alertas** block
(blockers hit, plus constructive feedback on whether the window's work
serves the Epic's goal and which backlog cards are easy follow-ups). Each
Epic's status verdict (Na trilha / Atrasado / Bloqueado) is shown inline at
its heading — there is no separate summary table. Output is a markdown
report file.

**Requires the Atlassian (Jira) MCP server connected** (server endpoint:
https://mcp.atlassian.com/v1/mcp/authv2) — every step calls
`mcp__atlassian__*` tools. Do not scrape Jira via WebFetch as a substitute.

**If `mcp__atlassian__*` tools aren't available**, the Atlassian MCP isn't
connected. Tell the user to run `/mcp`, add/select the **Atlassian** connector,
complete the OAuth login, confirm `/mcp` shows "Connected to atlassian", then
retry.

**If the MCP is listed as connected but tools fail** (auth errors, empty
results, "not authorized", or calls that hang) — the session/token likely went
stale. Tell the user to **re-authenticate or re-enable** the connector: run
`/mcp`, select **Atlassian**, and re-run its login (or toggle the server off
and on), then retry the skill.

## Inputs

- **Project key** (required): e.g. `TEAM`, `ACME`. This is the JQL project key,
  *not* a board ID. If unknown/ambiguous, list with
  `mcp__atlassian__getVisibleJiraProjects` and confirm.
- **Window days** (optional, default **14** — a biweekly sprint, vs.
  `jira-project-health`'s 7-day default): look-back for Finalizados,
  Em andamento activity, and blocker comments. User-overridable ("last 7
  days").

## Core model (shared with `jira-project-health` — read that skill's "Core
model" section if you haven't; summarized here)

- **Macro unit = Epic.** Each In-Progress Epic gets its own section.
- **In-Progress = native `statusCategory`**, filtered via the English JQL key
  `statusCategory = "In Progress"` (language-agnostic; never filter on
  localized display strings).
- **Never trust the custom "Epic Status" field** if the client's `CONTEXT.md`
  flags it as a stale legacy field — real status is computed (see Step 6
  below).
- **Cards within an Epic** — per the client's `CONTEXT.md`/linkage model
  (e.g. one observed client uses the union of `parent = <EPIC>` and
  `issue in linkedIssues("<EPIC>", "Iniciativa Filha")`).

## Workflow

### 0. Resolve the client
Invoke the `client-context` skill's `resolve_client_root()` to find
`<client_root>` (walk-up from cwd, or ask if that fails). Read
`<client_root>/CONTEXT.md`, `EPIC-STANDARDS.md`, and `VOCABULARY.md` — needed
throughout the steps below.

### 1. cloudId (once per session, cache it)
Try `cloud_id` from `<client_root>/TRACKER.md` first. If absent or the call
fails with an auth/resource error, call
`mcp__atlassian__getAccessibleAtlassianResources`; take the `id` (UUID)
and `url` (hostname for browse links, e.g. `trilliab3.atlassian.net`), and
update `TRACKER.md` with the corrected value.

### 2. Find In-Progress Epics
```
mcp__atlassian__searchJiraIssuesUsingJql
  cloudId: <id>
  jql: 'project = <KEY> AND issuetype = Epic AND statusCategory = "In Progress" ORDER BY updated DESC'
  fields: [summary, status, duedate, description, assignee]
  maxResults: 100
  responseContentFormat: markdown
```
Keep the field list minimal (not `*all`) so this stays inline/jq-able — full
characteristics aren't needed here, only objective text and due date.

### 3. Per Epic: discover just the two fields the screenshot tracks
Unlike `jira-project-health`'s full characteristics sweep, this skill only
needs **Tipo do Projeto** (Operacional/Estratégico) and **Foco** — check
`<client_root>/VOCABULARY.md`'s custom-fields table for this client's actual
field names, these are examples from one observed client. Get the
field-name map once via `mcp__atlassian__getJiraIssue` with `expand: names`,
`fields: ["*all"]` on any one Epic (saved to file; custom-field ids are
instance-global so this is reusable across all Epics in this run):
```bash
jq -r 'to_entries[] | select(.value | test("Tipo do Projeto|Classe|Foco"; "i"))' /tmp/names.json
```
Re-query all Epics with just those `customfield_*` ids (small, jq-able). If
neither field exists on this project, omit the column rather than guessing.

### 4. Per Epic: collect cards within it, with assignee
Two JQL searches (union, dedup by key) — per the linkage model from Step 0:
```
project = <KEY> AND parent = <EPIC>
issue in linkedIssues("<EPIC>", "Iniciativa Filha")
```
Fields: `summary, description, status, statusCategory, duedate, assignee,
resolution, resolutiondate, issuetype, project`. `description` is the
card's own scope/acceptance-criteria text (distinct from the Epic-level
`description` already fetched in step 2/3 for "Onde estamos indo") — it
backs Step 7's Alertas comparison against the Epic's charter goal.
`assignee.displayName` is required here (not optional like in
`jira-project-health`) — every bullet in the output needs a name attached.

Classify each card (this classification feeds Step 7's bullets directly):
- **Finalizado** = `resolutiondate` falls inside the window
  (`resolutiondate >= -<N>d`).
- **Em andamento / Revisão** = `statusCategory = "In Progress"` (or a status
  name containing "Revis"/"Review"), `updated` inside the window, not yet
  resolved.

Cards with no assignee still count (credit nobody falsely) — render as
`— sem responsável` in its bullet (Step 7) and note it under Alertas e
lacunas instead.

Cards that are neither Finalizado nor Em andamento (open, untouched this
window) aren't discarded — keep this backlog pool per Epic. It isn't
rendered as its own list, but Step 7's Alertas sub-section draws on it to
spot easy follow-up cards.

### 5. Per Epic: comments in the window → blocker detection and per-card updates
Same call shape as `jira-project-health` step 5, scoped to this Epic's cards:
```
key in (<card keys>) AND updated >= -<N>d
fields: ["summary","assignee","comment","parent"]
```
Filter comments to `created` within the window. Flag any comment whose body
matches (case-insensitive): `bloque|blocker|impediment|aguardando
(retorno|aprova)`. These feed the **Bloqueios** sub-list under the Epic
(card link, author, timestamp, excerpt) — kept as its own standalone
callout inside Bloqueios e alertas (Step 7), so execs can scan it
independently for red flags.

Non-blocker comments aren't discarded: keep any that surface a decision,
dependency, or notable context (e.g. "alinhado com Zilde em 20-05", "MR
aberto: feat: X", scope changed mid-sprint) — these become a short
paraphrased update appended inline to that card's bullet in Step 7. Only
attach an update if it adds information beyond the card's own
summary/status — don't pad a bullet with a restated obvious fact.

### 6. Status verdict per Epic
Compute one of three labels (never read from "Epic Status"):
- **Bloqueado** — at least one blocker found in step 5.
- **Atrasado** — Epic `duedate` has passed and open cards remain, OR no card/
  comment activity at all in the window (stagnation) — reuse
  `jira-project-health`'s schedule-health/stagnation heuristic.
- **Na trilha** — default, none of the above.

This verdict renders inline at the Epic's heading in Step 8 — e.g.
`## [TEAM-436](link) — "Router V2" — **Bloqueado**` — there is no separate
summary table.

### 7. Per Epic: card bullets (Finalizados / Em andamento) and Bloqueios e alertas

Render Step 4's classified cards as bullets, one list per status:

```
**Finalizados:** *(sorted chronologically by resolution date, oldest first)*
- <YYYY-MM-DD> — <summary> — <assignee> ([<KEY>](link)) — <comment update, if any>

**Em andamento / Revisão:**
- <summary> — <assignee> ([<KEY>](link)) — <comment update, if any>
```

Where `<YYYY-MM-DD>` is the `resolutiondate` truncated to date only (no time
component). Sort the Finalizados list ascending by `resolutiondate` before
rendering — first bullet = card resolved earliest, last bullet = most recent.

The comment-update suffix is the paraphrased non-blocker comment kept in
Step 5 for that card — omit the dash and suffix entirely if that card has
no qualifying comment, don't pad it. If a card's only relevant comment is a
flagged blocker, don't restate it here — the blocker already lives in
Bloqueios below; leave the bullet's suffix off so the same fact isn't said
twice. Cards with no assignee render as `— sem responsável` (see Step 4).

If an Epic has zero card activity in the window, state that in one line
instead of empty bullet lists (this is also a stagnation signal feeding
Step 6's Atrasado verdict).

Then, under the same Epic, a **Bloqueios e alertas** block with two
labeled sub-groups:

```
**Bloqueios:**
- [<CARD-KEY>](link) — <author> | <timestamp> — <comment excerpt>

**Alertas:**
1. <constructive feedback point>
```

**Bloqueios** is exactly Step 5's flagged-comment list (card link, author,
timestamp, excerpt) — unchanged from before.

**Alertas** is new per-Epic synthesis, not data-hygiene (that's the
separate top-level "Alertas e lacunas" footer in Step 8) — write it by
comparing:
1. The Epic's own charter description (goal / roadmap / deliverables /
   scope, per `EPIC-STANDARDS.md`, already fetched in Step 2/3) against
   what actually got classified as Finalizado/Em andamento this window —
   say plainly whether this window's work clearly serves the Epic's stated
   goal/deliverables. Report this either way, not only when it's bad news.
2. The backlog pool kept in Step 4 (open cards under the Epic, untouched
   this window) — call out any that read as an easy, low-friction follow-up
   to what just shipped (e.g. its `description` explicitly depends on or
   extends a Finalizado card's scope). Cite the specific card key(s).

Keep Alertas short (no hard cap, but don't pad) — omit it entirely for an
Epic if there's nothing substantive beyond "on track, no obvious
follow-ups."

### 8. Output
Write a markdown file under **`<client_root>/_reports/`** (create the dir if
missing): `<client_root>/_reports/retro-<KEY>-<YYYY-MM-DD>.md`.

**Hyperlink every Epic and card key**: `[<KEY>](https://<host>/browse/<KEY>)`
everywhere a key appears — Epic headings, Finalizados/Em andamento bullets,
Bloqueios e alertas. Never print a bare key.

```markdown
# Retrospectiva quinzenal — <KEY>
Projeto: <KEY> — <project name>
Período: <window start> – <window end> (últimos <N> dias)

## [<EPIC-KEY>](link) — "<summary>" — <Na trilha / Atrasado / Bloqueado>
**Tipo:** <Tipo do Projeto> · **Foco:** <Foco> · **Time:** <assignees, deduped>

**Onde estamos indo:** <objective (description / Breve descrição) + nearest
upcoming milestone — soonest open card duedate, or the Epic's own duedate if
cards have none>

**Finalizados:** *(sorted chronologically by resolution date, oldest first)*
- <YYYY-MM-DD> — <summary> — <assignee> ([<CARD-KEY>](link)) — <comment update, if any>

**Em andamento / Revisão:**
- <summary> — <assignee> ([<CARD-KEY>](link)) — <comment update, if any>

**Bloqueios e alertas:**

**Bloqueios:**
- [<CARD-KEY>](link) — <author> | <timestamp> — <comment excerpt>

**Alertas:**
1. <constructive feedback: progress-vs-goal and/or easy follow-up cards>

(repeat per Epic)

## Alertas e lacunas
1. ... (cards with no assignee, stale Epic Status field, Epics with no
   Tipo/Foco field, etc.)
```

Then echo a short summary in chat (Epic count, status breakdown — N na
trilha / N atrasados / N bloqueados, total blocker count).

See `<client_root>/EPIC-STANDARDS.md` and `VOCABULARY.md` for the
company-specific conventions an Epic/card is judged against.

### 9. Optional delivery (only if the user asks)
- **Email**: needs the Gmail MCP authenticated (`mcp__claude_ai_Gmail__*`).
  Don't block the report on this.
- **Confluence**: `mcp__atlassian__createConfluencePage`. Pass the report's
  markdown verbatim as `body` with `contentFormat: "markdown"` — no manual
  HTML conversion needed, Confluence renders tables/headings/links from
  markdown directly.
  - **Destination (Trillia default only — ask other clients where to
    publish)**: space **DMGP** (id `6174015553`), under the **Sprint
    Reports** page (id `6224642051`, itself a child of "ML GenAI Platform -
    Conteúdo Interno"). Create the page with `spaceId: "6174015553"`,
    `parentId: "6224642051"`.
  - If the "Sprint Reports" parent doesn't exist yet (new space/first run),
    create it first under the user-specified parent page
    (`mcp__atlassian__createConfluencePage` with no body beyond a one-line
    description), then create the report page under *that* id.
  - **Title**: `Retrospectiva quinzenal — <KEY> — <YYYY-MM-DD>` (matches the
    report file's date).
  - If the user names a different space/parent page, use that instead — the
    DMGP ids above are just Trillia's known default, not a hardcoded
    requirement for every client.

## Notes
- **Board-scoped retro (e.g. a team's "Downstream" board) instead of a whole
  project**: a Jira board's scope is its own saved JQL filter, which often
  does *not* match the Epic-In-Progress macro model above (may span multiple
  projects, or filter by a team/cell field rather than Epic status — see
  the client's `VOCABULARY.md` → "Sub-boards within a project"). There is no MCP tool to
  read a board's saved filter, and `board = <id>` in JQL silently returns
  zero results instead of erroring — don't guess. Ask the user to paste the
  filter from Jira (board settings → "Edit filter query"), run that JQL
  verbatim (plus `updated >= -<N>d`), then bucket results into Finalizados
  (`resolutiondate` in window) / Em andamento (`statusCategory` In Progress)
  per parent Epic same as usual — but if the board mixes substantive Epics
  with high-volume Support/Service Request tickets, split those into a
  separate "Suporte e Acessos" aggregate-by-assignee section instead of
  forcing every ticket into the Epic-macro structure.
- Default window is 14 days (biweekly); user-overridable.
- Run once per project (separate report files per project key).
- Localized statuses: filter via the English JQL key, read display names
  as-is.
- If a `searchJiraIssuesUsingJql`/`getJiraIssue` result is saved to a file,
  probe with `jq 'keys'` before extracting — saved schema is
  `{issues:{nodes:[...]}}`, and `.[0].text` deprecation notices may precede
  data in some tool shapes.
