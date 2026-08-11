# Agent Orchestration

## Agent roster

| Agent | When to use |
|---|---|
| manager | Decompose complex multi-step/multi-domain user requests, dispatch to specialists. |
| architect | System design, scalability, architectural trade-offs. Mandatory first step in any `manager` plan. |
| planner | Plan a single feature/refactor implementation (task-scoped, not request-scoped like `manager`). |
| code-reviewer | General code review for quality/security/maintainability. Use after any code change. |
| security-reviewer | Vulnerability detection after code touching input, auth, endpoints, secrets. |
| go-reviewer | Go code review — idiomatic Go, concurrency, error handling. |
| java-reviewer | Java/Spring Boot code review — layered architecture, JPA, security. |
| python-resolver | Python code review — idiomatic Python, type hints, error handling. |
| rust-reviewer | Rust code review — ownership/borrowing, error handling, async correctness. |
| go-build-resolver | Fix Go build/vet/lint failures. |
| java-build-resolver | Fix Java/Maven/Gradle build/compile/dependency failures. |
| rust-build-resolver | Fix Rust build/borrow-checker/clippy failures. |
| tdd-guide | Enforce write-tests-first methodology, 80%+ coverage. |
| refactor-cleaner | Remove dead code/duplicates via knip/depcheck/ts-prune. |
| doc-updater | Update docs/codemaps. Mandatory last step in any `manager` plan. |

## Agent vs skill

**Agent** = own context window, tool access, autonomy; does multi-step judgment where the path isn't predetermined.
**Skill** = reference knowledge or fixed procedure loaded into the caller's context; no autonomy, caller already decided to act.

When adding new capability: if it requires branching judgment across multiple steps, it's an agent. If it's know-how or a checklist consumed by an already-deciding caller, it's a skill.

## Skill<->agent frontmatter convention

Skill files may declare `agents: ["name", ...]` (or `agents: ["*"]` for any agent) to indicate intended callers.
Agent files may declare `skills: ["name", ...]` to indicate skills that agent is expected to invoke via the Skill tool.

**Limitation:** this is a documentation/prompt convention, not access control. The Skill tool resolves by name only and does not check caller identity. Treat these fields as a discoverability aid for humans and tooling (e.g. `skill-health`), not a security boundary. Don't force-fit links that aren't real — an empty `skills: []` is correct when no genuine overlap exists.

## Caveman-ultra dispatch

Subagents run in fresh sessions and do not inherit the main session's caveman flag file (`~/.claude/.caveman-active`). There is no peer-to-peer agent messaging in Claude Code — a dispatched agent's only channel back is its final text report to whoever invoked it. So every dispatch prompt must explicitly request caveman-ultra style:

```
Respond in caveman-ultra style per the caveman skill (abbreviate, strip conjunctions,
one word where one word suffices). Keep code blocks, error messages, and security
warnings verbatim — do not compress those.
```

## Invoking manager

Subagents in this harness cannot call the Agent tool themselves — no nested delegation. So `manager` cannot invoke `architect` on its own, even though architect validation is mandatory. Whoever invokes `manager` (the main session, or another agent with Agent-tool access) must:

1. Invoke `architect` first with the user's request.
2. Invoke `manager` second, including architect's output in the prompt.
3. Execute each step of manager's returned dispatch table in order, via the Agent tool.

If `manager` is invoked without an architect design already in the prompt, it will refuse to fabricate a plan and instead ask its caller to run step 1 first.

## Manager plan sequencing rules

1. `architect` always runs first — mandatory plan composition/validation step, never skipped.
2. Build-resolvers (`go-build-resolver`, `java-build-resolver`, `rust-build-resolver`) run before reviewers touching the same code.
3. Reviewers (`code-reviewer`, `security-reviewer`, `go-reviewer`, `java-reviewer`, `python-resolver`, `rust-reviewer`) run in parallel when they don't touch the same files.
4. `tdd-guide` runs before implementation-heavy steps when TDD is requested.
5. `doc-updater` always runs last — mandatory documentation step, included even if the user's request never mentioned documentation.
