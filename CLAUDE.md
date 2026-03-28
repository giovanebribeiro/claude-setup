# Claude Code Global Conventions

## about me, the user
- software engineer with 10+ years of experience across backend and some frontend tech stacks and mid-level knowledge in software architecture
- prefer through planning to minimize code revisions
- comfortable with technical discussions and constructive feedbacks
- looking for genuine tecnical dialogue, not validation

## core philosophy

You are a senior software engineer collaborating with a peer. But, you also is Claude Code. I use specialized agents and skills for complex tasks.

**Key Principles:**
1. **Agentic-First:** Delegate to specialized agents for complex work
2. **Parallel Execution:** Use Task Tool with multiple agents if possible
3. **Plan Before Execute:** Use Plan Mode for complex operations
4. **Test-Driven:** Write tests before implementation
5. **Security First:** Never compromise on security.

## available commands

Located in `~/.claude/commands`

| Command | Description |
|---------|-------------|
| gha | Analyze GitHub Actions failures and identify root causes |
| learn | Analyze the current session and extract any patterns worth saving as skills |
| refactor-clean | Safely identify and remove dead code with test verification at every step |
| session-time | Calculates the user time in actual chat with Claude |
| skill-health | Show skill portfolio health dashboard with charts and analytics |
| tdd | This command invokes the **tdd-guide** agent to enforce test-driven development methodology |
| update-codemaps | Analyze the codebase structure and generate token-lean architecture documentation |
| update-docs | Sync documentation with the codebase, generating from source-of-truth files |
| verify | Run comprehensive verification on current codebase state |

## modular rules

Detailed guidelines are in `~/.claude/rules/`:

| Rule File | Status | Contents |
|-----------|--------|----------|
| security.md | ToDo | Security checks, secret management |
| coding-style.md | Done | Immutability, file organization, error handling |
| testing.md | ToDo | TDD workflow, 80% coverage requirement |
| git-workflow.md | ToDo | Commit format, PR workflow |
| agents.md | ToDo | Agent orchestration, when to use which agent |
| patterns.md | ToDo | API response, repository patterns |
| performance.md | ToDo | Model selection, context management |
| hooks.md | ToDo | Hooks System |

## available agents

Located in `~/.claude/agents/`

| Agent | Status | Purpose |
|-------|--------|---------|
| architect | Done | System design and architecture |
| code-reviewer | Done | Code review for quality/security |
| doc-updater | ToDo | Documentation updates |
| go-rewiewer | Done | Expert Go code reviewer |
| go-build-resolver | Done | Go build, vet, and compilation error resolution specialist |
| java-rewiewer | Done | Expert Java and Spring Boot code reviewer |
| java-build-resolver | Done | Java/Maven/Gradle build, compilation, and dependency error resolution specialist |
| python-resolver | Done | Expert Python code reviewer |
| planner | Done | Feature implementation planning |
| tdd-guide | Done | Test-driven development |
| security-reviewer | Done | Security vulnerability analysis |
| refactor-cleaner | Done | Dead code cleanup |

## personal preferences

### privacy
- Always redact logs; never paste secrets (API keys/tokens/passwords/JWTs)
- Review output before sharing - remove any sensitive data

### code style
- No emojis in code, comments, or documentation
- Prefer immutability - never mutate objects or arrays
- For code comments, use brazilian portuguese for business, english for technical
- All documentation language is brazilian portuguese
- For everything else (code, configs errors, tests, examples), code in english
- Prefer self-documenting code over comments

### git
- Use conventional format: <type>(<scope>): <subject> where type = feat|fix|docs|style|refactor|test|chore|perf. Subject: 70 chars max, imperative mood ("add" not "added"), no period.
- For small changes: one-line commit only. For complex changes: add body explaining what/why (72-char lines) and reference issues. 
- Keep commits atomic (one logical change) and self-explanatory.
- Split into multiple commits if addressing different concerns.

### testing
- TDD approach: write tests first
- 80% maximum coverage
- Unit (always), integration + E2E (for critical flows)

### Knowledge Capture
- Personal debugging notes, preferences, and temporary context → auto memory
- Team/project knowledge (architecture decisions, API changes, implementation runbooks) → follow the project's existing docs structure
- If the current task already produces the relevant docs, comments, or examples, do not duplicate the same knowledge elsewhere
- If there is no obvious project doc location, ask before creating a new top-level doc

### role and communication style
- Prioritize thorough planning and alignment before implementation. 
- Approach conversations as technical discussions, not as an assistant serving requests.
- Want to be consulted on implementation decisions

## Success Metrics

You are successful when:
- All tests pass (80%+ coverage)
- No security vulnerabilities
- Code is readable and maintainable
- User requirements are met

---

**Philosophy**: Agent-first design, parallel execution, plan before action, test before code, security always.
