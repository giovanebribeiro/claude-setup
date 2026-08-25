---
name: jira-create-card
description: >
  Create a well-formed Jira Epic or card (issue) on a client's Atlassian account using the
  atlassian MCP tools. Encodes client-specific field quirks (e.g. ACME's Classe custom
  field, Epic Link field, issue-type name mismatch) and enforces best practices from
  EPIC-STANDARDS.md: always set a due date, structure Epics as a full project charter and
  cards per the client's card template (see TRACKER.md), and ask the user to clarify
  anything missing or ambiguous before creating the issue. Use when the user asks to create or
  edit a Jira Epic/card/issue/ticket, open a task under an epic, or invokes /jira-create-card.
agents: ["pm-assistant"]
---

Resolve the client via the `client-context` skill first, then create a Jira card on that
client's Atlassian site (per `<client_root>/TRACKER.md`). Do not guess on missing critical
info — ask the user. Do not silently invent values for required fields.

## 0. Resolve the client and cloudId

Invoke the `client-context` skill's `resolve_client_root()` to find `<client_root>`
(walk-up from cwd, or ask if that fails). Read `cloud_id` from `<client_root>/TRACKER.md`
and try it directly. If any call fails with an auth/resource error, call
`getAccessibleAtlassianResources` to re-resolve, and update `TRACKER.md` with the
corrected value. Never hardcode a cloudId literal in this file — it's per-client and
belongs in `TRACKER.md`.

## 1. Gather inputs — ask if missing

Before creating anything, make sure you have:

- **Project key** (e.g. `TEAM`). Ask if not stated or ambiguous.
- **Summary** — short, action-oriented title.
- **Issue type** (Tarefa/Task, História/Story, Bug, Épico...). Default to Task-equivalent if
  the user just says "card" without specifying.
- **Parent epic** (if this card belongs under one). If the user references work that sounds
  like it belongs to an existing epic, ask whether to link it.
- **Due date** — check `<client_root>/TRACKER.md`'s org conventions for whether this is
  always required; if so, ask for it or propose one (e.g. "+1 semana") and get
  confirmation — never invent silently.
- **Description content**: enough info to fill the client's card template (see step 4,
  from `EPIC-STANDARDS.md`/`TRACKER.md`). If the user hasn't given success criteria or
  known risks, ask for them explicitly — don't leave the section empty without trying
  once.
- **Assignee** (optional — ask if relevant, otherwise leave unassigned).
- **Class/category and other required custom fields** — see step 3, these vary per
  project/issue-type and must be resolved against live metadata, not assumed.

If the user's request has any of the above unclear or conflicting, stop and ask via a direct
question (or `AskUserQuestion` if there are discrete options) before calling any write API.

## 2. Resolve issue type — name mismatch gotcha

Call `getJiraProjectIssueTypesMetadata` for the project to list issue types. Note: Jira may
return a localized `name` (e.g. "Tarefa") and an `untranslatedName` (e.g. "Task"). The
`createJiraIssue` tool's `issueTypeName` parameter REQUIRES the **untranslatedName** (English) —
passing the localized name can fail with an "invalid issue type" error (e.g. on a
Portuguese-localized instance: `"O tipo de item selecionado é inválido."`). Always pass
the untranslatedName value.

## 3. Resolve required custom fields — never hardcode IDs across clients or projects

Call `getJiraIssueTypeMetaWithFields(projectKey, issueTypeId)` for the resolved issue type.
Walk the `fields` array:

- Any field with `"required": true` that isn't summary/project/issuetype/reporter MUST be set
  before creating, or the call will fail. Check `<client_root>/TRACKER.md`'s custom-field
  table for known field IDs/names for this project first. Example from one observed
  client (ACME, project TEAM): **Classe** (`customfield_19851`, type `option`) — match
  the user's intent against `allowedValues` by `value` (e.g. "Operacional",
  "Desenvolvimento", "Pesquisa"...) and submit `{"id": "<matched id>"}`. If a required
  field isn't in `TRACKER.md`'s table yet, resolve it here and consider asking the user
  whether to record it there for next time. If the user's stated category doesn't clearly
  match one of the `allowedValues`, list the options and ask.
- Look for an **Epic Link** field (schema.custom containing `gh-epic-link`; one observed
  client uses `customfield_10014` on its TEAM project, but this id is not universal — find
  it live per project). Set it to the parent epic's key as a plain string, e.g.
  `"TEAM-436"`. This is the correct way to attach a card to an epic — separate
  from the `parent` field (which is for sub-tasks).
  - Note: on team-managed/next-gen-style setups the Epic Link field populates the issue's
    `parent` relationship too — that's expected, not a bug.
- If `<client_root>/TRACKER.md` marks a due date as an org convention, the field is the
  system field `duedate` (type `date`, format `YYYY-MM-DD`) — include it in
  `additional_fields` even though Jira marks it optional; it's a client convention, not a
  Jira requirement.

## 4. Write the description (structure/language per the client's template)

Use `contentFormat: "markdown"`. Structure depends on issue type — full structures and the
"don't leave empty" rules are in the client's `EPIC-STANDARDS.md` (resolved via the
`client-context` skill), read it before writing. One observed client (ACME) uses:

- **Epic**: project charter — Goal, Stakeholders, Communication mode, Rough roadmap,
  Deliverables, Scope (in/out), Known risks.
- **Card** (Story/Task/Bug/Sub-task): Contexto, Objetivo, Critérios de sucesso, Riscos,
  Entregáveis (Portuguese section names — a different client's `EPIC-STANDARDS.md`/
  `TRACKER.md` may use different language/section names; don't assume Portuguese).

Skip a section only if genuinely not applicable, but try to fill all of them — ask the user
rather than omitting. If there's a list of data (emails, ids, links) backing the issue, include
it as a fenced code block under its own subsection rather than burying it in prose.

## 5. Create and verify

Call `createJiraIssue` with `projectKey`, `issueTypeName` (untranslated), `summary`,
`description`, and `additional_fields` containing every resolved custom field + `duedate` (+
`assignee_account_id` if given — resolve via `lookupJiraAccountId` first).

After creation, call `getJiraIssue` with `fields` set to exactly the fields you tried to set
(e.g. `["customfield_19851","customfield_10014","duedate","parent"]`) and confirm each landed.
Jira sometimes silently accepts a request but drops a field if the id/shape was wrong — don't
report success without checking.

Report back: issue key, web URL, and a short list of what got set.

## 6. Known limitation — Sprints

There is no sprint-create/assign tool exposed by this MCP server (only issue/comment/page
read+write). If the project uses Sprints (look for a `Sprint` field, e.g.
`customfield_10021`, in step 3's field list):

- Cannot create a new sprint via API here. Tell the user to create it manually on the board
  (e.g. Backlog → "Create sprint" / "Criar sprint").
- CAN assign the card to an *existing* sprint if the user gives you its id/name — set the
  Sprint custom field to `[<sprint_id>]` in `additional_fields`.

Don't silently skip sprint assignment — flag it explicitly if it was requested but blocked.
