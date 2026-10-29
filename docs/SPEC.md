# OMEGA-LOOP: Autonomous Multi-Model Engineering & Governance Protocol

Status: **installed globally** (user level, all projects). This document is the spec; the running implementation lives in `~/.claude/omega/` and `~/.claude/skills/omega-loop/`. If they diverge, the scripts win and this file gets fixed.

## 1. Overview

OMEGA-LOOP turns **Claude Code** into the kernel orchestrator of a plan → build → adversarial audit → verify → commit loop, combining:

* **Persistent state (`.omega/`)**: a small finite state machine plus an append-only ledger, so a session (or a different provider) can resume exactly where the work stopped.
* **Provider auto-detection and failover**: Claude Code and OpenAI Codex back each other up. Detection runs on every session, so enabling Codex later needs no configuration.
* **Executable guardrails**: per-extension validator scripts run before the adversarial review.
* **Zero self-grading**: whoever wrote the diff never reviews it.

## 2. Roles and providers

| Role | Primary | Fallback | Isolation |
| --- | --- | --- | --- |
| Orchestrator / kernel | Claude Code (main session) | Codex via `codex_takeover.sh` (manual, from terminal) | Owns state machine, terminal, git. |
| Architect | Codex (`architect_prompt.md`) | Claude, architect persona | Design and invariants only, no code. |
| Builder | Claude Code | Codex (`codex exec --full-auto`) | Minimal atomic edits. |
| Adversarial auditor | Codex | Fresh `claude -p` session | Sees only plan + diff; never the build conversation. |

Notes on what is real:
* ChatGPT has no CLI, so it is not an automated provider; its Architect role goes to Codex or to the Claude persona.
* There is no `--fresh-session` / `--persona` flag. A "fresh session" is `claude -p <prompt> --no-session-persistence --tools ""`; a "persona" is a role stated in the prompt.
* Provider modes: `HYBRID_MULTI_MODEL` (Codex binary present, `codex --version` ok, `codex login status` ok) and `CLAUDE_ISOLATED_FULL_STACK` (otherwise).

### Failover (token exhaustion or any provider error)

* **Codex unavailable or exhausted** → its role moves to Claude immediately; the loop never stops.
* **Claude exhausted** → the audit falls back to Codex automatically. The rest of the loop resumes from the terminal with `~/.claude/omega/codex_takeover.sh`, which reads `.omega/` and continues. Claude cannot launch it once exhausted, so state files must be kept current at every transition.
* `audit.sh` tries providers in order (Codex then Claude in hybrid mode, Claude then Codex otherwise). A provider counts as failed on non-zero exit **or** when its output contains no JSON object with a `verdict`. Every attempt and failure is appended to the ledger.
* If no provider produces a valid verdict, the result is `REJECTED` with exit code 2. A missing verdict is never treated as approval.

## 3. Files

Global install (never committed to a project):

```text
~/.claude/
├── settings.json                 # SessionStart hook
├── skills/omega-loop/SKILL.md    # /omega-loop entry point
└── omega/
    ├── session_start.sh          # hook: detects providers, injects OMEGA context into every new chat
    ├── audit.sh                  # isolated adversarial audit with failover
    ├── codex_takeover.sh         # resume the loop with Codex when Claude is out of tokens
    ├── projects.json             # per-project settings, kept outside the repos
    ├── agents/                   # adversary_prompt.md, architect_prompt.md
    └── skills/                   # fallback_manager.py, validate.sh, *_validator.*
```

Per-repo runtime state (created on first loop; `.omega/` is in the global gitignore):

```text
.omega/
├── STATE.json              # {"state": ..., "iteration": N}
├── PROVIDER_STATE.json     # last provider detection
├── PLAN.md                 # goals, invariants, acceptance criteria, proof commands
├── ledger/DECISIONS.log    # append-only: transitions, audits, provider switches, failures
├── drafts/latest.diff      # diff under review
└── SUMMARY.md              # written at commit time
```

### States

`RECON` → `STRATEGY` → `EXECUTION` → `ADVERSARIAL_AUDIT` → `VERIFICATION` → `COMMITTED`.
`ADVERSARIAL_AUDIT` returns to `EXECUTION` on rejection.

## 4. Automatic activation

A `SessionStart` hook in `~/.claude/settings.json` runs `session_start.sh` for every new chat, including the Claude Code VS Code extension. It re-detects Codex (no files written) and injects the current provider mode plus the instruction to follow the `omega-loop` protocol.

Scope of the instruction: non-trivial code changes in a git repo. Questions, code reading and one-line edits skip the loop, otherwise the plan gate would fire on every message. Project `CLAUDE.md` rules (commit confirmations, changelog, no `--no-verify`) always take precedence.

## 5. Guardrails (validators)

`validate.sh <files...>` dispatches by extension; extensions without a validator are skipped, and exit 1 means at least one validator failed.

| Extension | Validator | Enforces |
| --- | --- | --- |
| `.scad` | `scad_validator.py` | `difference() { ... }` structure, `h + 0.2` padding on subtractions, no `minkowski()` |
| `.swift` | `swift_validator.sh` | no `DispatchQueue.main` (use `@MainActor`), no `ObservableObject` (use `@Observable`), `[weak self]` warning |
| `.cs`, `.csx` | `cs_validator.csx` | no `Task.Run` for I/O, `ReadOnlySpan` hint; skipped if `dotnet-script` is missing |
| `.js`, `.html` | `ng_validator.js` | AngularJS only: no `$scope`, `track by` on `ng-repeat`, `$onDestroy` cleanup for `$on` |

Per-project settings live in `~/.claude/omega/projects.json`, keyed by the git root (`~` is expanded), so they never touch the repo. This file is machine-local: it names real project paths, so it is never committed, synced or published:

```json
{ "~/path/to/angularjs-repo": { "ng": true } }
```

The AngularJS validator is off by default (false positives on Vue/Node code) and on for repos listed with `"ng": true`; `OMEGA_NG=1` forces it once.

Known trade-off: the Swift rules are strict and may flag legitimate code in projects that still use `ObservableObject`. Relax them per project if that happens.

## 6. Execution protocol

### Phase 0: Bootstrap (every run)
1. Run `fallback_manager.py` to refresh `.omega/PROVIDER_STATE.json`.
2. Write `STATE.json` = `RECON`; log to `DECISIONS.log` from here on.

### Phase 1: Recon and strategy
1. Read repo rules and docs, detect the stack and its validators.
2. Architect role (Codex or Claude persona) defines invariants.
3. Write `PLAN.md`: goals, invariants, observable acceptance criteria, exact proof commands (build, lint, tests).
4. **Gate**: the user approves the plan explicitly before any edit.

### Phase 2: Execution
1. `STATE` = `EXECUTION`. Minimal atomic edits.
2. Run `validate.sh` on the changed files.
3. Stage the diff: `git add -N` for new files, then `git diff > .omega/drafts/latest.diff`.

### Phase 3: Adversarial audit
1. `STATE` = `ADVERSARIAL_AUDIT`; run `audit.sh <iteration>`.
2. Verdict JSON:
```json
{ "verdict": "APPROVED | REJECTED", "iteration_round": 1,
  "critical_flaws": ["Line N: ..."], "required_remediations": ["..."], "security_score": 0 }
```
3. `REJECTED` → log, increment iteration, back to Phase 2 with the remediations. After 5 iterations stop and ask the user. Unparseable output counts as one rejection, then ask.
4. `APPROVED` → log and continue.

The auditor's rules: reject guardrail and project-rule violations, hunt race conditions, null/edge cases, leaks and missing disposal, and ignore comments that claim safety.

### Phase 4: Verification and commit
1. `STATE` = `VERIFICATION`; run the proof commands from `PLAN.md`.
2. If green: write `SUMMARY.md` (changes, proof output, provider used per phase), set `COMMITTED`, commit following the project's own commit rules (ask first where the project requires it).

## 7. Operating notes

* Test the fallback path without uninstalling anything: `OMEGA_FORCE_FALLBACK=1 ~/.claude/omega/audit.sh 1`.
* Run helper scripts from the repo root; `.omega/` is created relative to the current directory.
* To add a project-specific validator or setting, edit `projects.json` and `validate.sh`, never the repo.

## 8. Privacy rules

* This spec and every committed or synced OMEGA file use only placeholders and `~`: no absolute user paths, personal names, emails, hostnames or secrets.
* Real project paths live only in `~/.claude/omega/projects.json` (local).
* Ledger and `SUMMARY.md` may quote command output: never include credentials, and keep `.omega/` out of git (global gitignore).
