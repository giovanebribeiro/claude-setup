# claude-setup

My configurations, scripts, skills, etc., for Claude Code. Got many things (including this structure) from this [amazing](https://github.com/affaan-m/everything-claude-code) project.

## Dependencies

* serena ([https://oraios.github.io/serena/02-usage/030_clients.html](https://oraios.github.io/serena/02-usage/030_clients.html))
* rtk ([https://github.com/rtk-ai/rtk](https://github.com/rtk-ai/rtk))
* caveman ([https://github.com/JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman))

### Installation

Just clone this repo as:

```
# in a fresh install, before the claude installation:
$ git clone https://github.com/GiovaneRibeiro-neuro/claude-setup.git ~/.claude

# or, in an existent claude install:

$ cp -r ~/.claude ~/.claude.bkp
$ git clone https://github.com/GiovaneRibeiro-neuro/claude-setup.git ~/.claude
$ cp -r ~/.claude.bkp/**/*.* ~/.claude/
```

## Tracker integration (optional)

`tracker-integrator` / `/track-work` create tracker (Jira) epics/tasks from an approved
plan. They read connection details, custom-field mappings, and the card/epic description
template from `agent-data/tracker/config.md` (and optionally `vocabulary.md` for a
stakeholder roster) — both gitignored, so they don't exist after a fresh clone and won't
be created automatically.

Before using `tracker-integrator` or `/track-work` on a new machine:

1. `mkdir -p ~/.claude/agent-data/tracker`
2. Create `agent-data/tracker/config.md` with your org's cloud id, project keys, required
   custom-field IDs, and description template (see the skeleton structure documented in
   `skills/tracker-adapter/adapters/jira.md`).
3. Optionally add `agent-data/tracker/vocabulary.md` if you want stakeholder names
   auto-suggested for an Epic's "Stakeholders" section.

These files hold org-specific values on purpose and are never committed — see
`rules/common/git-workflow.md` and `.gitignore`.
