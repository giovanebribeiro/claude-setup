# Git Workflow

## Commit message format

Conventional commits: `<type>(<scope>): <subject>`, where type =
feat|fix|docs|style|refactor|test|chore|perf. Subject: 70 chars max, imperative mood
("add" not "added"), no period.

- Small changes: one-line commit only.
- Complex changes: add a body explaining what/why (72-char lines), reference issues.
- Keep commits atomic (one logical change) and self-explanatory.
- Split into multiple commits if addressing different concerns.

## Tracker issue key in commit subject (opt-in)

When a commit implements work created via `tracker-integrator` / `/track-work`, put the
tracker issue key in the scope:

```
feat(PROP-123): add retry to card sync
```

- **Opt-in, not mandatory** for every commit — only for work that actually went through
  tracker-card creation. Most commits in this repo won't have one, and that's fine.
- A `PostToolUse` hook (`skills/tracker-adapter/hooks/commit-key-reminder.sh`) inspects
  every `git commit` invocation and prints a reminder to stderr — **informational only,
  never blocks the commit**.
- The key-format regex lives in `skills/tracker-adapter/config.json`
  (`issue_key_regex`), shared by the hook and the `tracker-adapter` skill so it's defined
  once, not duplicated.
- This is not status automation — moving the card in the tracker is a manual step (or one
  you ask an agent to do explicitly), not a background watcher. See
  `rules/common/agents.md`'s `tracker-integrator` entry for why: the approval gate design
  deliberately avoids polling the tracker for status changes.

### Worked examples

Commit with a tracker key — the hook prints:
```
$ git commit -m "feat(PROP-123): add retry to card sync"
[tracker] Commit references PROP-123 — remember to move that card.
```

Commit without a tracker key — the hook prints a lighter reminder, doesn't block:
```
$ git commit -m "chore: bump deps"
[tracker] Commit has no tracker key in its subject. If this work is tracked, use: <type>(<KEY>): <subject> — see rules/common/git-workflow.md.
```
