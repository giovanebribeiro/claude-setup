# Jira Adapter

Concrete implementation of the `tracker-adapter` operation contract for Jira, via the
Atlassian MCP (`mcp__atlassian__*`). Ported from a working Trillia-specific version — the
*shape* of every step below is proven; the *values* (cloudId, custom field IDs, project
keys, description template) are org-specific and must come from
`~/.claude/agent-data/tracker/config.md`, never hardcoded here.

Do not guess on missing critical info — ask the user. Do not silently invent values for
required fields.

## 0. Resolve cloudId

Read `cloud_id` from `agent-data/tracker/config.md`. Try it directly. If any call fails
with an auth/resource error, call `getAccessibleAtlassianResources` to re-resolve, and
update `config.md` with the corrected value.

## 1. `resolve_project(hint?)`

If a hint (project key) was given, use it directly. Otherwise call
`getVisibleJiraProjects` and ask the user to pick, or check `agent-data/tracker/config.md`'s
project table for a default. Never hardcode a key.

## 2. Gather inputs for `create_epic` / `create_task` — ask if missing

Before creating anything, make sure you have:

- **Project key** — from `resolve_project`.
- **Summary** — short, action-oriented title.
- **Issue type** (Task, Story, Bug, Epic...). Default to the org's task-equivalent if the
  user just says "card" without specifying — check `config.md` for the default.
- **Parent epic**, if this is a task belonging under one.
- **Due date**, if `config.md` marks it as an org convention (some orgs require it on
  every issue even though Jira itself doesn't) — check before assuming it's optional.
- **Description content**: enough to fill the org's description template (see step 5).
  If the user hasn't given success criteria or risks, ask for them explicitly rather than
  leaving the section empty.
- **Assignee** (optional — ask if relevant, otherwise leave unassigned).
- **Custom fields required by this project/issue-type** — resolved live in step 4, not
  assumed from memory.

If anything above is unclear or conflicting, stop and ask before calling any write API.

## 3. Resolve issue type — name mismatch gotcha

Call `getJiraProjectIssueTypesMetadata` for the project. Jira may return a localized
`name` (e.g. a translated label) and an `untranslatedName` (English). The
`createJiraIssue` tool's `issueTypeName` parameter requires the **untranslatedName** —
passing the localized name can fail with an "invalid issue type" error. Always pass the
untranslatedName value.

## 4. Resolve required custom fields — never hardcode IDs across projects

Call `getJiraIssueTypeMetaWithFields(projectKey, issueTypeId)`. Walk the `fields` array:

- Any field with `"required": true` that isn't summary/project/issuetype/reporter MUST be
  set before creating, or the call fails. Check `agent-data/tracker/config.md`'s
  custom-field table for known field IDs/names for this project; if a required field isn't
  in that table yet, resolve it here and consider asking the user whether to record it in
  `config.md` for next time.
- Match the user's intent against a field's `allowedValues` by `value` — if it doesn't
  clearly match one, list the options and ask.
- Look for an **Epic Link**-style field (schema.custom containing an epic-link type) to
  attach a task to a parent epic — set it to the parent's key as a plain string. This is
  separate from the `parent` field, which is for sub-tasks.
  - Note: on team-managed/next-gen-style projects, the Epic Link field may also populate
    the issue's `parent` relationship — that's expected, not a bug.
- If `config.md` marks a due date as an org convention, the field is the system field
  `duedate` (type `date`, format `YYYY-MM-DD`) — include it in `additional_fields` even if
  Jira itself marks it optional.

## 5. Write the description

Use `contentFormat: "markdown"`. Structure and language come from
`agent-data/tracker/config.md`'s description template section — read it before writing;
don't assume a fixed structure or language here, since that's an org preference, not a
Jira requirement.

Skip a template section only if genuinely not applicable — ask the user rather than
omitting. If there's a list of data (emails, ids, links) backing the issue, include it as
a fenced code block under its own subsection rather than burying it in prose.

## 6. Create and verify

Call `createJiraIssue` with `projectKey`, `issueTypeName` (untranslated), `summary`,
`description`, and `additional_fields` containing every resolved custom field (+
`assignee_account_id` if given — resolve via `lookupJiraAccountId` first).

After creation, call `getJiraIssue` with `fields` set to exactly the fields you tried to
set and confirm each landed — Jira sometimes accepts a request but silently drops a field
if the id/shape was wrong. Don't report success without checking.

Report back: issue key, web URL, and a short list of what got set.

## 7. `link_parent_child(parent, child)`

Set the child's Epic Link field (or equivalent, per step 4) to the parent's key, or use
`createIssueLink` with the org's configured "epic/initiative" link-type id from
`agent-data/tracker/config.md` if the org uses issue links rather than Epic Link for this.

## 8. Known limitation — Sprints

There is no sprint-create/assign tool exposed by this MCP server (only issue/comment/page
read+write). If the project uses Sprints (look for a Sprint-type custom field in step 4):

- Cannot create a new sprint via API here — tell the user to create it manually on the
  board.
- CAN assign the card to an *existing* sprint if the user gives you its id/name — set the
  Sprint custom field to `[<sprint_id>]` in `additional_fields`.

Don't silently skip sprint assignment — flag it explicitly if it was requested but blocked.

## Example

Real MCP call sequence for "create an epic with one linked task under project PROP"
(values illustrative — actual field IDs come from `config.md`):

```
getVisibleJiraProjects()                                   -> confirms "PROP" exists
getJiraProjectIssueTypesMetadata("PROP")                    -> Epic untranslatedName "Epic"
getJiraIssueTypeMetaWithFields("PROP", "<epic-type-id>")    -> required: customfield_XXXXX (Category)
createJiraIssue({
  projectKey: "PROP", issueTypeName: "Epic", summary: "...",
  description: "<markdown per config.md template>",
  additional_fields: { customfield_XXXXX: {"id": "<matched allowedValue id>"} }
})                                                            -> "PROP-456"
getJiraIssue("PROP-456", fields: ["customfield_XXXXX"])       -> confirms field landed

createJiraIssue({
  projectKey: "PROP", issueTypeName: "Task", summary: "...",
  description: "...",
  additional_fields: { customfield_YYYYY: "PROP-456" }        // Epic Link field
})                                                            -> "PROP-457"
```
