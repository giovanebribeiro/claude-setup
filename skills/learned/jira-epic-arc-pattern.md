# Jira Epic Creation — ARC Project Pattern

**Extracted:** 2026-04-07
**Context:** Creating Jira epics in the ARC (Archimedes/Riskpack) project following the
team's established description structure. Applies when the Atlassian MCP is unavailable
and when the user provides a title + reference epic + owner.

## Problem
Creating well-structured Jira epics in the ARC project requires:
- Matching the team's 4-section description template (in ADF format)
- Setting the correct custom fields for the project
- Falling back to REST API when the Atlassian MCP server is not attached to the session

## Environment Variables (defined in ~/.my_shell_stuff)
| Var | Purpose |
|---|---|
| `$JIRA_NEUROTECH_URL` | `https://neurotech.atlassian.net` — correct base URL for the ARC project |
| `$JIRA_USERNAME` | Atlassian email for Basic Auth |
| `$JIRA_API_TOKEN` | Atlassian API token |
| `$JIRA_ACCOUNT_ID` | Your Jira account ID (assignee/reporter) |

> Note: `$JIRA_URL` points to `neurolake.atlassian.net` which is a different workspace.
> Always use `$JIRA_NEUROTECH_URL` for ARC project operations.

## Workflow

### Step 1 — Check if Atlassian MCP is running
Use `ListMcpResourcesTool`. If "atlassian" is absent from the server list, fall back to REST API.

### Step 2 — Fetch reference epic (to verify/mirror structure)
```bash
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  -H "Accept: application/json" \
  "$JIRA_NEUROTECH_URL/rest/api/3/issue/ARC-XXXX?fields=description,summary,issuetype"
```

### Step 3 — Build description (ADF 4-section template)
The ARC project uses this structure for all epics:

1. **H2: "1. Problema / Oportunidade de Negócio"** — Current pain, why this matters now
2. **Rule separator**
3. **H2: "2. Visão Estratégica (Elevator Pitch)"** — One paragraph, desired future state
4. **Rule separator**
5. **H2: "3. Escopo Macro"**
   - **H3: "IN Scope (Faremos):"** — What will be done (inline after bold label)
   - **H3: "OUT of Scope (Não faremos agora):"** — Explicit exclusions (inline after bold label)
6. **Rule separator**
7. **H2: "4. Métricas de Sucesso (KPIs)"** — 3–5 measurable outcomes, `hardBreak`-separated

All H2 headings use `"marks": [{ "type": "strong" }]`.
H3 headings use a bold label followed by plain inline text in the same node.

### Step 4 — Create the epic via REST API
```bash
curl -s -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
  -X POST \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d @/tmp/epic_payload.json \
  "$JIRA_NEUROTECH_URL/rest/api/3/issue"
```

Minimal required payload fields:
```json
{
  "fields": {
    "project": { "key": "ARC" },
    "issuetype": { "id": "10000" },
    "summary": "<title>",
    "assignee": { "accountId": "<JIRA_ACCOUNT_ID>" },
    "reporter": { "accountId": "<JIRA_ACCOUNT_ID>" },
    "description": { "type": "doc", "version": 1, "content": [...] }
  }
}
```

### ARC Project custom field reference
| Field | Purpose | Known values |
|---|---|---|
| `customfield_10625` | Quarter | Q1.2026=`17178`, Q2.2026=`17179`, Q3.2026=`17180`, Q4.2026=`17181` |
| `customfield_10611` | Tipo | Padrão=`12373` |
| `customfield_10612` | Tamanho | M (Médio)=`12379` |
| `customfield_10158` | Squad | Archimedes=`13526` |
| `customfield_10017` | Cor do épico | `"dark_green"` (string, not object) |
| `customfield_11822` | flag Sim/Não | Sim=`15838` |
| `customfield_11821` | flag Sim/Não | Não=`15837` |

## Prompt Pattern (from .claude/prompts/create-epic.md)
```
I want create an epic issue in Jira. The description must have the structure
present in https://neurotech.atlassian.net/browse/ARC-XXXX epic, the owner
of the task is my user (giovane.ribeiro@trilliab3.com.br) the project is ARC
and title for this epic is: "<title>"

Think a lot.
```

## When to Use
- User asks to create a Jira epic in the ARC project
- User references a `create-epic.md`-style prompt or a `neurotech.atlassian.net/browse/ARC-*` URL
- Atlassian MCP is not running → use REST API fallback
- User provides: title + (optionally) reference epic + owner
