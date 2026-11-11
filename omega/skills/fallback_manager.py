#!/usr/bin/env python3
"""Detects available providers. Runs on every run: Codex enabled later is picked up automatically.
Writes .omega/PROVIDER_STATE.json in the cwd (current repo)."""
import subprocess, json, os, shutil, datetime, urllib.request

def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None

def codex_ok():
    if not shutil.which("codex"):
        return False, "binary not found"
    if (r := run(["codex", "--version"])) is None or r.returncode != 0:
        return False, "--version failed"
    r = run(["codex", "login", "status"])
    if r is None or r.returncode != 0:
        return False, "not logged in (codex login)"
    return True, "ok"

# (kind, base url, models endpoint, JSON -> model ids). Both expose an Anthropic-compatible /v1/messages.
LOCAL = [
    ("ollama", "http://localhost:11434", "/api/tags", lambda d: [m["name"] for m in d.get("models", [])]),
    ("lmstudio", "http://localhost:1234", "/v1/models", lambda d: [m["id"] for m in d.get("data", [])]),
]

def qwen_local():
    """First local Qwen model served by Ollama or LM Studio, or None."""
    for kind, url, path, ids in LOCAL:
        try:
            with urllib.request.urlopen(url + path, timeout=2) as r:
                for m in ids(json.load(r)):
                    if "qwen" in m.lower():
                        return {"kind": kind, "url": url, "model": m}
        except Exception:
            continue
    return None

def main_model():
    """Orchestrator model: OMEGA_MAIN_MODEL, else ~/.claude/settings.json 'model'."""
    m = os.environ.get("OMEGA_MAIN_MODEL")
    if not m:
        try:
            m = json.load(open(os.path.expanduser("~/.claude/settings.json"))).get("model", "")
        except Exception:
            m = ""
    return m.lower()

def delegate(main, qwen):
    """Model for non-orchestrator work: Qwen, else Sonnet (Haiku if Sonnet already orchestrates)."""
    if qwen:
        return "qwen"
    return "haiku" if "sonnet" in main else "sonnet"

def main():
    ok, why = codex_ok()
    qwen, mm = qwen_local(), main_model()
    state = {
        "codex_available": ok,
        "codex_detail": why,
        # ChatGPT has no CLI: architect role always on the Claude persona (or codex if available)
        "chatgpt_available": False,
        "main_model": mm,
        "qwen": qwen,
        "delegate": delegate(mm, qwen),
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
