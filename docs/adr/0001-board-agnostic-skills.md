# PM-assistant skills are board-agnostic but were once company-specific

> **Status: superseded by [0002](./0002-client-scoped-context.md).** The second
> paragraph below (company-specific quirks staying hardcoded, `VOCABULARY.md`/
> `EPIC-STANDARDS.md` living at a repo root) is no longer accurate — kept here
> for history, not as current guidance. Originally written in the `pmo` repo;
> moved here when `pm-assistant`/`jira-*` were promoted to global agents/skills
> (see 0002), since this decision now applies to tooling that isn't scoped to
> any single repo.

The original `jira-project-health` and `jira-create-card` skills were written against the author's own boards (PROP, EP) and could easily have hardcoded those project keys as defaults. We decided against that: project/board keys are always a required runtime input, never a default baked into a skill or agent. This is so the skills/agent can be reused as-is by another manager who points them at their own Jira boards, without editing skill code.

~~Company-specific quirks (Trillia's "Classe" custom field, the cloudId for `trilliab3.atlassian.net`, the Contexto/Objetivo/Critérios card-description structure) are *not* abstracted away — those stay hardcoded, since genericizing them would add speculative complexity for a hypothetical multi-tenant use case that isn't needed yet. Vocabulary and standards specific to Trillia live in `VOCABULARY.md` and `EPIC-STANDARDS.md` at the repo root.~~ See 0002 — the multi-tenant case stopped being hypothetical once a second client showed up, so this got reversed.
