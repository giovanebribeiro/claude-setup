# Track Work

Create tracker (Jira) epics/tasks for an already-approved implementation plan, then stop
for explicit confirmation before implementation begins.

## Instructions

1. Confirm an approved plan already exists in this conversation (from `architect`/
   `manager`/`planner`, or an ad-hoc plan the user just approved). If none exists, stop
   and ask the user to approve one first — do not invent scope to track.
2. Dispatch: Agent tool, `subagent_type: tracker-integrator`, prompt = the approved plan's
   content + `$ARGUMENTS` (if given, as the project/board key hint).
3. Relay `tracker-integrator`'s report (created issue keys + links) back to the user
   verbatim.
4. Do **not** continue into implementation after this — `tracker-integrator` stops after
   reporting, and this command does too. The user's explicit confirmation in conversation
   is what unblocks implementation, not this command completing.

This is opt-in — never invoked automatically by `manager` or any other flow, only when the
user explicitly wants a piece of approved work tracked before/while work starts.

## Example

Right after a plan for "add retry logic to card-sync worker" is approved:

```
/track-work PROP
```

Output relayed to the user:

```
Created PROP-456 (epic: "Add retry logic to card-sync worker") and three linked tasks:
PROP-457, PROP-458, PROP-459.

https://<site>.atlassian.net/browse/PROP-456
...

Implementation will not start until you confirm — reply to proceed.
```

## Arguments

$ARGUMENTS — optional project/board key. If omitted, `tracker-integrator` resolves it via
the adapter's `resolve_project` operation rather than guessing.
