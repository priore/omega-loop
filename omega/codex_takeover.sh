#!/usr/bin/env bash
# Run from the terminal when Claude is out of tokens: Codex resumes the loop from the state in .omega/.
# Usage: ~/.claude/omega/codex_takeover.sh   (from the repo root)
set -eu
[ -f .omega/PLAN.md ] || { echo "No .omega/PLAN.md: nothing to resume" >&2; exit 1; }
codex exec --full-auto --skip-git-repo-check "Resume the OMEGA-LOOP protocol in place of Claude (out of tokens).
Read .omega/STATE.json, .omega/PLAN.md, .omega/ledger/DECISIONS.log and the repo rules (CLAUDE.md).
Continue from the phase indicated in STATE.json: minimal atomic edits, then 'git diff > .omega/drafts/latest.diff'.
For the audit run ~/.claude/omega/audit.sh <iteration> (it will use a provider other than you where possible).
Update STATE.json and DECISIONS.log at every transition. Do not commit without the user's confirmation."
