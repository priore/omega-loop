#!/usr/bin/env bash
# audit.sh <iteration> — isolated review of .omega/drafts/latest.diff. Stdout = JSON verdict.
# Failover: tries providers in order; if one is exhausted/errors/returns no valid JSON, moves to the next.
# Order: codex then claude (if codex is available), otherwise claude then codex. If claude is exhausted, codex steps in.
set -u
O="$(cd "$(dirname "$0")" && pwd)"; IT="${1:-1}"
python3 "$O/skills/fallback_manager.py" >/dev/null
MODE=$(python3 -c 'import json;print(json.load(open(".omega/PROVIDER_STATE.json"))["mode"])')
[ "${OMEGA_FORCE_FALLBACK:-0}" = 1 ] && MODE=CLAUDE_ISOLATED_FULL_STACK
P="$(cat "$O/agents/adversary_prompt.md")

iteration_round: $IT

## PLAN
$(cat .omega/PLAN.md 2>/dev/null)

## DIFF
$(cat .omega/drafts/latest.diff)"

# extracts the last JSON object with "verdict" from the raw output; exit 1 if none
extract() { python3 -c '
import sys,json
t=sys.stdin.read(); d=json.JSONDecoder(); best=None; i=t.find("{")
while i!=-1:
    try:
        o,e=d.raw_decode(t,i)
        if isinstance(o,dict) and "verdict" in o: best=o
        i=t.find("{",e)
    except ValueError: i=t.find("{",i+1)
if not best: sys.exit(1)
print(json.dumps(best))'; }

run_codex()  { codex exec --sandbox read-only --skip-git-repo-check "$P" </dev/null 2>&1; }
run_claude() { claude -p "$P" --no-session-persistence --tools "" </dev/null 2>&1; }

if [ "$MODE" = HYBRID_MULTI_MODEL ]; then ORDER="codex claude"; else ORDER="claude codex"; fi
for prov in $ORDER; do
  [ "$prov" = codex ] && ! command -v codex >/dev/null && continue
  echo "[audit] provider=$prov" >&2
  if OUT=$(run_$prov) && V=$(printf '%s' "$OUT" | extract); then
    echo "$(date +%FT%T) audit it=$IT provider=$prov" >> .omega/ledger/DECISIONS.log
    echo "$V"; exit 0
  fi
  echo "[audit] $prov failed/exhausted, trying the next one" >&2
  echo "$(date +%FT%T) audit it=$IT provider=$prov FAILED: $(printf '%s' "$OUT" | tail -c 200 | tr '\n' ' ')" >> .omega/ledger/DECISIONS.log
done
echo '{"verdict":"REJECTED","critical_flaws":["no provider produced a valid verdict"],"required_remediations":["retry later or ask the user"],"security_score":0}'
exit 2
