#!/usr/bin/env bash
# Installa OMEGA-LOOP a livello utente (~/.claude). Sicuro da rilanciare: aggiorna senza toccare le tue impostazioni.
set -eu
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude"
command -v python3 >/dev/null || { echo "Serve python3." >&2; exit 1; }
command -v claude  >/dev/null || echo "Attenzione: 'claude' non trovato nel PATH (Claude Code è necessario)."

mkdir -p "$DEST/omega" "$DEST/skills/omega-loop"
# non sovrascrive projects.json (impostazioni locali dell'utente)
[ -f "$DEST/omega/projects.json" ] && KEEP=$(cat "$DEST/omega/projects.json") || KEEP=""
cp -R "$SRC/omega/." "$DEST/omega/"
rm -f "$DEST/omega/projects.example.json"
if [ -n "$KEEP" ]; then printf '%s\n' "$KEEP" > "$DEST/omega/projects.json"; else echo '{}' > "$DEST/omega/projects.json"; fi
cp "$SRC/skill/SKILL.md" "$DEST/skills/omega-loop/SKILL.md"
chmod +x "$DEST"/omega/*.sh "$DEST"/omega/skills/*.sh "$DEST"/omega/skills/*.py

# hook SessionStart in settings.json (con backup, idempotente)
python3 - <<'PY'
import json, os, shutil
p = os.path.expanduser("~/.claude/settings.json")
s = json.load(open(p)) if os.path.exists(p) else {}
if os.path.exists(p): shutil.copy(p, p + ".omega.bak")
cmd = "bash $HOME/.claude/omega/session_start.sh"
lst = s.setdefault("hooks", {}).setdefault("SessionStart", [])
if not any(h.get("command") == cmd for e in lst for h in e.get("hooks", [])):
    lst.append({"hooks": [{"type": "command", "command": cmd}]})
json.dump(s, open(p, "w"), indent=2)
PY

# .omega/ fuori da git in tutti i tuoi repo
G=$(git config --global core.excludesfile || true)
if [ -z "$G" ]; then G="$HOME/.gitignore_global"; git config --global core.excludesfile "$G"; fi
G="${G/#\~/$HOME}"
touch "$G"; grep -qx '.omega/' "$G" || echo '.omega/' >> "$G"

echo "OMEGA-LOOP installato. Apri una NUOVA chat di Claude Code e scrivi: /omega-loop <cosa vuoi fare>"
command -v codex >/dev/null && echo "Codex rilevato: modalità ibrida attiva." || echo "Codex non rilevato: funziona solo con Claude (si attiverà da solo se lo installi)."
