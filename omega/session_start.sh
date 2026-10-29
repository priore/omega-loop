#!/usr/bin/env bash
# Hook SessionStart: rileva provider (senza scrivere file) e inietta il contesto OMEGA nella nuova chat.
S=$(OMEGA_NOWRITE=1 python3 "$HOME/.claude/omega/skills/fallback_manager.py" 2>/dev/null)
MODE=$(printf '%s' "$S" | python3 -c 'import json,sys;print(json.load(sys.stdin)["mode"])' 2>/dev/null || echo UNKNOWN)
python3 - "$MODE" <<'PY'
import json,sys
ctx=f"""OMEGA-LOOP ACTIVE (global). Provider mode: {sys.argv[1]} (Codex re-detected each session).
For any non-trivial code change (multi-step feature/fix/refactor) in a git repo, follow the `omega-loop` skill protocol: plan with approval gate, builder edits, isolated adversarial audit via ~/.claude/omega/audit.sh (writer never reviews own diff), verify, commit per project rules. Skip for questions, reading code, one-line trivial edits. Project CLAUDE.md rules take precedence."""
print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":ctx}}))
PY
