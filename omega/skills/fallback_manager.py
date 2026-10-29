#!/usr/bin/env python3
"""Rileva provider disponibili. Eseguito a ogni run: Codex attivato dopo viene visto da solo.
Scrive .omega/PROVIDER_STATE.json nella cwd (repo corrente)."""
import subprocess, json, os, shutil, datetime

def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None

def codex_ok():
    if not shutil.which("codex"):
        return False, "binary assente"
    if (r := run(["codex", "--version"])) is None or r.returncode != 0:
        return False, "--version fallita"
    r = run(["codex", "login", "status"])
    if r is None or r.returncode != 0:
        return False, "non loggato (codex login)"
    return True, "ok"

def main():
    ok, why = codex_ok()
    state = {
        "codex_available": ok,
        "codex_detail": why,
        # ChatGPT non ha CLI: ruolo architect sempre su Claude persona (o codex se disponibile)
        "chatgpt_available": False,
        "mode": "HYBRID_MULTI_MODEL" if ok else "CLAUDE_ISOLATED_FULL_STACK",
        "checked_at": datetime.datetime.now().isoformat(timespec="seconds"),
    }
    if os.environ.get("OMEGA_NOWRITE"):
        print(json.dumps(state)); return
    os.makedirs(".omega/ledger", exist_ok=True)
    os.makedirs(".omega/drafts", exist_ok=True)
    with open(".omega/PROVIDER_STATE.json", "w") as f:
        json.dump(state, f, indent=2)
    print(json.dumps(state, indent=2))

if __name__ == "__main__":
    main()
