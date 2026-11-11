#!/usr/bin/env bash
# subagent.sh "<prompt>" — runs a delegated task on the resolved delegate model (stdout = answer).
# Resolution (fallback_manager.py): local Qwen (Ollama/LM Studio) > Sonnet; Haiku when Sonnet is the orchestrator.
# Set OMEGA_MAIN_MODEL to the orchestrator's model (sonnet|opus|fable) for exact resolution.
set -u
O="$(cd "$(dirname "$0")" && pwd)"
S=$(OMEGA_NOWRITE=1 python3 "$O/skills/fallback_manager.py")
J() { printf '%s' "$S" | python3 -c "import json,sys;d=json.load(sys.stdin);print($1)"; }
D=$(J 'd["delegate"]')
if [ "$D" = qwen ]; then
  export ANTHROPIC_BASE_URL=$(J 'd["qwen"]["url"]') ANTHROPIC_AUTH_TOKEN=local ANTHROPIC_API_KEY=
  exec claude -p "$1" --model "$(J 'd["qwen"]["model"]')" --no-session-persistence --tools "Read,Grep,Glob" </dev/null
fi
exec claude -p "$1" --model "$D" --no-session-persistence --tools "Read,Grep,Glob" </dev/null
