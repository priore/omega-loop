#!/usr/bin/env bash
# Installs OMEGA-LOOP at user level (~/.claude). Safe to re-run: updates without touching your settings.
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude"
command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
command -v claude  >/dev/null || echo "Warning: 'claude' not found in PATH (Claude Code is required)."

mkdir -p "$DEST/omega" "$DEST/skills/omega-loop"
# does not overwrite projects.json (the user's local settings)
[ -f "$DEST/omega/projects.json" ] && KEEP=$(cat "$DEST/omega/projects.json") || KEEP=""
cp -R "$SRC/omega/." "$DEST/omega/"
rm -f "$DEST/omega/projects.example.json"
if [ -n "$KEEP" ]; then printf '%s\n' "$KEEP" > "$DEST/omega/projects.json"; else echo '{}' > "$DEST/omega/projects.json"; fi
cp "$SRC/skill/SKILL.md" "$DEST/skills/omega-loop/SKILL.md"
chmod +x "$DEST"/omega/*.sh "$DEST"/omega/skills/*.sh "$DEST"/omega/skills/*.py

# SessionStart hook in settings.json (with backup, idempotent)
python3 - <<'PY'
import json, os, shutil
p = os.path.expanduser("~/.claude/settings.json")
s = json.load(open(p)) if os.path.exists(p) else {}
if os.path.exists(p): shutil.copy(p, p + ".omega.bak")
cmd = "bash $HOME/.claude/omega/session_start.sh"
# model routing: Opus plans, Sonnet builds, Haiku for subagents
s["model"] = "opusplan"
s.setdefault("env", {})["CLAUDE_CODE_SUBAGENT_MODEL"] = "haiku"
lst = s.setdefault("hooks", {}).setdefault("SessionStart", [])
if not any(h.get("command") == cmd for e in lst for h in e.get("hooks", [])):
    lst.append({"hooks": [{"type": "command", "command": cmd}]})
json.dump(s, open(p, "w"), indent=2)
PY

# keep .omega/ out of git in all your repos
G=$(git config --global core.excludesfile || true)
if [ -z "$G" ]; then G="$HOME/.gitignore_global"; git config --global core.excludesfile "$G"; fi
G="${G/#\~/$HOME}"
touch "$G"; grep -qx '.omega/' "$G" || echo '.omega/' >> "$G"

echo "OMEGA-LOOP v$(cat "$SRC/VERSION") installed. Open a NEW Claude Code chat and type: /omega-loop <what you want to do>"
command -v codex >/dev/null && echo "Codex detected: hybrid mode active." || echo "Codex not detected: running Claude-only (it will be picked up automatically if you install it)."
