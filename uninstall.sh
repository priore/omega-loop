#!/usr/bin/env bash
# Removes OMEGA-LOOP from ~/.claude (hook included). Does not touch your repos or the .omega/ folders.
set -eu
python3 - <<'PY'
import json, os
p = os.path.expanduser("~/.claude/settings.json")
if os.path.exists(p):
    s = json.load(open(p)); cmd = "bash $HOME/.claude/omega/session_start.sh"
    lst = s.get("hooks", {}).get("SessionStart", [])
    for e in lst: e["hooks"] = [h for h in e.get("hooks", []) if h.get("command") != cmd]
    s["hooks"]["SessionStart"] = [e for e in lst if e["hooks"]] if lst else lst
    if not s["hooks"]["SessionStart"]: del s["hooks"]["SessionStart"]
    json.dump(s, open(p, "w"), indent=2)
PY
rm -rf "$HOME/.claude/omega" "$HOME/.claude/skills/omega-loop"
echo "OMEGA-LOOP removed."
