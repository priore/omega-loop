---
name: omega-loop
description: Autonomous multi-model engineering loop (plan → build → isolated adversarial audit → verify → commit) with automatic Codex detection and Claude-only fallback. Use when the user invokes /omega-loop or asks for the OMEGA-LOOP protocol on a task.
---

# OMEGA-LOOP (global)

Tooling lives in `~/.claude/omega/`. Per-repo state lives in `.omega/` of the current repo (globally git-ignored). Task = skill args.

Rules: the writer never reviews its own diff. Project CLAUDE.md rules still win (commit-per-phase confirmations, CHANGELOG, etc.). Never use `--no-verify`.

## Failover tra provider
- Codex senza token/errore: il suo ruolo (architect, builder, auditor) passa subito a Claude, senza fermare il loop. `audit.sh` lo fa da solo (codex → claude).
- Claude senza token: `audit.sh` ripiega su Codex; per il resto il loop riprende da terminale con `~/.claude/omega/codex_takeover.sh` (legge `.omega/` e continua). Claude non può lanciarlo se è esaurito: chiedi all'utente di farlo, e tieni sempre STATE.json/DECISIONS.log aggiornati così la ripresa è possibile.
- Ogni passaggio di provider va scritto in DECISIONS.log.

## Phase 0 — Bootstrap (every run, re-detects Codex)
1. `python3 ~/.claude/omega/skills/fallback_manager.py` → `.omega/PROVIDER_STATE.json`. Report mode: `HYBRID_MULTI_MODEL` (codex ok) or `CLAUDE_ISOLATED_FULL_STACK`.
2. Write `.omega/STATE.json` `{"state":"RECON","iteration":0}`. Append every transition/decision to `.omega/ledger/DECISIONS.log`.

## Phase 1 — Recon + Strategy
1. Read repo rules/docs, detect stack. Validators in `~/.claude/omega/skills/validate.sh <files>` (scad, swift, cs; AngularJS only with `OMEGA_NG=1`).
2. Architect role: Codex mode → `codex exec --sandbox read-only` with `~/.claude/omega/agents/architect_prompt.md`; fallback → do it yourself as architect persona (no code). 
3. Write `.omega/PLAN.md`: goals, invariants, acceptance criteria, exact proof commands.
4. GATE: show the plan, get explicit user approval (AskUserQuestion) before any edit.

## Phase 2 — Execution (Builder)
State `EXECUTION`. Minimal atomic edits (Builder = you; in Codex mode may delegate to `codex exec --full-auto` if the user chose it). Run `validate.sh` on changed files. Then `git diff > .omega/drafts/latest.diff` (include untracked via `git add -N` first).

## Phase 3 — Adversarial audit
State `ADVERSARIAL_AUDIT`. Run `~/.claude/omega/audit.sh <iteration>`: uses Codex if available, else a fresh `claude -p` session with no tools and no memory of the build. Parse the JSON verdict.
- REJECTED: log flaws, iteration+1, back to Phase 2 with remediations. Max 5 iterations, then stop and ask the user.
- APPROVED: log, continue. Unparseable output = treat as REJECTED once, then ask user.

## Phase 4 — Verification + commit
State `VERIFICATION`: run the PLAN proof commands (build/tests). If green: write `.omega/SUMMARY.md`, state `COMMITTED`, commit following the project's commit rules (ask first if project requires it).
