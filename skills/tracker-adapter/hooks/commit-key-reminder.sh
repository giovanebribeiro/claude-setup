#!/bin/bash
# Reminds the user to move the tracker card after a git commit.
#
# Fires on every PostToolUse(Bash) call; no-ops unless the command was `git commit`.
# Informational only — never blocks the commit (always exits 0).
#
# Claude Code passes hook data via stdin as JSON: {"tool_input": {"command": "..."}, ...}

set -e

INPUT_JSON=$(cat)
[ -z "$INPUT_JSON" ] && exit 0

resolve_python_cmd() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s\n' python3
    return 0
  fi
  if command -v python >/dev/null 2>&1; then
    printf '%s\n' python
    return 0
  fi
  return 1
}

PYTHON_CMD="$(resolve_python_cmd 2>/dev/null || true)"
[ -z "$PYTHON_CMD" ] && exit 0

CMD=$("$PYTHON_CMD" -c "import json,sys
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))
except Exception:
    pass" <<< "$INPUT_JSON" 2>/dev/null || true)

case "$CMD" in
  *"git commit"*) ;;
  *) exit 0 ;;
esac

CONFIG="$HOME/.claude/skills/tracker-adapter/config.json"
REGEX=$("$PYTHON_CMD" -c "import json
try:
    print(json.load(open('$CONFIG')).get('issue_key_regex', '[A-Z][A-Z0-9]+-[0-9]+'))
except Exception:
    print('[A-Z][A-Z0-9]+-[0-9]+')" 2>/dev/null || echo '[A-Z][A-Z0-9]+-[0-9]+')

# Best-effort static extraction of the -m subject text from the command string.
MSG=$("$PYTHON_CMD" -c "import shlex,sys
try:
    args = shlex.split(sys.argv[1])
except ValueError:
    sys.exit(0)
for i, a in enumerate(args):
    if a in ('-m', '--message') and i + 1 < len(args):
        print(args[i + 1])
        break" "$CMD" 2>/dev/null || true)
[ -z "$MSG" ] && exit 0   # editor-based commit (no -m) — can't statically inspect, stay silent

if echo "$MSG" | grep -qE "$REGEX"; then
  KEY=$(echo "$MSG" | grep -oE "$REGEX" | head -1)
  echo "[tracker] Commit references $KEY — remember to move that card." >&2
else
  echo "[tracker] Commit has no tracker key in its subject. If this work is tracked, use: <type>(<KEY>): <subject> — see rules/common/git-workflow.md." >&2
fi

exit 0
