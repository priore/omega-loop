#!/usr/bin/env bash
# SessionStart hook: detects providers (without writing files) and injects the OMEGA context into the new chat.
# hook stdin may carry the session model; it feeds main-model detection
HM=$(python3 -c 'import json,sys;print(json.load(sys.stdin).get("model") or "")' 2>/dev/null)
S=$(OMEGA_MAIN_MODEL="${OMEGA_MAIN_MODEL:-$HM}" OMEGA_NOWRITE=1 python3 "$HOME/.claude/omega/skills/fallback_manager.py" 2>/dev/null)
MODE=$(printf '%s' "$S" | python3 -c 'import json,sys;print(json.load(sys.stdin)["mode"])' 2>/dev/null || echo UNKNOWN)
DEL=$(printf '%s' "$S" | python3 -c 'import json,sys;print(json.load(sys.stdin)["delegate"])' 2>/dev/null || echo sonnet)
python3 - "$MODE" "$DEL" <<'PY'
import json,sys
ctx=f"""OMEGA-LOOP ACTIVE (global). Provider mode: {sys.argv[1]} (Codex re-detected each session). Delegate model for non-orchestrator work: {sys.argv[2]} (local Qwen > Sonnet; Haiku if the orchestrator is Sonnet). Delegate side tasks with: OMEGA_MAIN_MODEL=<your model> ~/.claude/omega/subagent.sh "<prompt>".
For any non-trivial code change (multi-step feature/fix/refactor) in a git repo, follow the `omega-loop` skill protocol: plan with approval gate, builder edits, isolated adversarial audit via ~/.claude/omega/audit.sh (writer never reviews own diff), verify, commit per project rules. Skip for questions, reading code, one-line trivial edits. Project CLAUDE.md rules take precedence."""
print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":ctx}}))
PY
