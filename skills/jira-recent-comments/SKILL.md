---
name: jira-recent-comments
description: Reports recently-commented Jira cards for a project/board within a time window (e.g. last 4 days) — title, key, epic, browse link, and full comment content with author/timestamp. Use when user asks about recent Jira card updates, comments, activity on a board/project, or what happened on a Jira project recently.
agents: ["pm-assistant"]
---

# Jira Recent Comments

**Requires the Atlassian (Jira) MCP server connected** — all steps below
call `mcp__atlassian__*` tools. Do not attempt to scrape Jira via WebFetch
as a substitute.

**If `mcp__atlassian__*` tools aren't available**, the user hasn't installed
the Jira MCP yet. Tell them to use either:

- **Inside Claude Code**: run `/mcp`, pick "Add server" / select the
  **Atlassian** connector (covers Jira + Confluence) — remote MCP server,
  no local install needed — then complete the OAuth login that opens in
  the browser.
- **From a terminal**, add it directly via CLI:

  ```bash
  claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp/authv2
  ```

  then run `/mcp` inside Claude Code to complete the OAuth login.

Confirm it worked: `/mcp` should show "Connected to atlassian." Once
connected, retry this skill — the `mcp__atlassian__*` tools will be
available.

## Quick start

Given a project key (e.g. `PROP`) and a window in days (default 4), find every
issue with at least one comment created inside that window and print, per
issue: key, title, epic, browse link, and each in-window comment (author,
timestamp, full body).

## Workflow

0. **Resolve the client (optional but preferred)**: invoke the
   `client-context` skill's `resolve_client_root()` if you want to cross-check
   `cloud_id`/`site` against a known `<client_root>/TRACKER.md` — this skill's
   project-key input works standalone regardless of client, so this step is a
   consistency check, not a hard requirement the way it is for skills that
   read `VOCABULARY.md`/`EPIC-STANDARDS.md`.

1. **Get cloudId** (once per session, cache it): try `cloud_id` from
   `<client_root>/TRACKER.md` if step 0 resolved one; otherwise call
   `mcp__atlassian__getAccessibleAtlassianResources`. Take the `id` (UUID) of
   the relevant site.

2. **Compute cutoff**: today's date minus N days (window), as `YYYY-MM-DD`.

3. **Search candidate issues** — only issues `updated` within the window can
   have in-window comments, so narrow with JQL first:

   ```
   mcp__atlassian__searchJiraIssuesUsingJql
     cloudId: <id>
     jql: "project = <KEY> AND updated >= -<N>d ORDER BY updated DESC"
     fields: ["summary", "comment", "parent"]
     maxResults: 100
     responseContentFormat: markdown
   ```

   `parent` field carries the epic (issuetype "Épico"/"Epic") when the
   issue's hierarchy parent is an epic.

4. **Handle large output**: this call commonly exceeds the inline token
   limit and gets saved to a file (path given in the tool error/result).
   Don't try to read it with `Read` — use `jq`:

   ```bash
   jq -r '.[1].text' <saved-file>.json > /tmp/jira_window.json
   ```

   (`.[0].text` is usually an Atlassian deprecation notice, not data —
   check `.[0]` vs `.[1]` with `jq 'type'` if the shape looks off.)

5. **Filter comments to the window**, keep epic key as the sort/group key,
   and extract what's needed — emit one JSON object per comment so nothing
   breaks on newlines in the body:

   ```bash
   jq -c --arg since "<cutoff-date>" '
   .issues[] | select(.fields.comment.comments | length > 0) |
   .key as $k | .fields.summary as $s |
   (.fields.parent.key // "ZZZ-SEM-EPICO") as $epicKey |
   (.fields.parent.fields.summary // "Sem épico") as $epicName |
   .fields.comment.comments[] | select(.created >= $since) |
   {epicKey: $epicKey, epicName: $epicName, key: $k, summary: $s,
    author: .author.displayName, created: .created, body: .body}
   ' /tmp/jira_window.json | jq -s 'sort_by(.epicKey, .key, .created)' \
   > /tmp/jira_window_filtered.json
   ```

   Sorting by `epicKey` first is what makes the final print group cards by
   epic instead of by update time.

6. **Build the browse link** for each issue: `https://<site>/browse/<KEY>`
   (site hostname from the cloud resource's `url` field, e.g.
   `trilliab3.atlassian.net`).

7. **Print grouped by epic, epic code on its own line above the cards**.
   Walk `/tmp/jira_window_filtered.json` in order (already sorted by
   `epicKey, key, created`); start a new epic block whenever `epicKey`
   changes, and within an epic block start a new card subsection whenever
   `key` changes (a card can have multiple comments in the window):

   ```
   # Épico <epic-key> — <epic-title>

   ## <KEY> — <title>
   Link: https://<site>/browse/<KEY>
   Comentário(s):
   - <author> | <timestamp> — <full body>

   ## <KEY2> — <title2>
   Link: https://<site>/browse/<KEY2>
   Comentário(s):
   - <author> | <timestamp> — <full body>

   # Épico <epic-key-2> — <epic-title-2>

   ## <KEY3> — <title3>
   ...
   ```

   Cards with no epic (`epicKey` == `ZZZ-SEM-EPICO`) go in a final
   `# Sem épico` block, last.

## Notes

- Default window is 4 days if the user doesn't specify one.
- "Board" in casual speech usually means the Jira *project key*, not a
  literal Scrum/Kanban board object — use the project key in JQL.
- If a project key is ambiguous or unknown, list visible projects first
  with `mcp__atlassian__getVisibleJiraProjects` (also paginate/save-to-file
  for large sites) and ask the user to confirm the key.
- Comment `body` may be Atlassian markdown (from `responseContentFormat:
  markdown`) — print as-is, don't re-render.
