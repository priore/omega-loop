#!/usr/bin/env bash
# Da terminale quando Claude ha finito i token: Codex riprende il loop dallo stato in .omega/.
# Uso: ~/.claude/omega/codex_takeover.sh   (nella root del repo)
set -eu
[ -f .omega/PLAN.md ] || { echo "Nessun .omega/PLAN.md: niente da riprendere" >&2; exit 1; }
codex exec --full-auto --skip-git-repo-check "Riprendi il protocollo OMEGA-LOOP al posto di Claude (token esauriti).
Leggi .omega/STATE.json, .omega/PLAN.md, .omega/ledger/DECISIONS.log e le regole del repo (CLAUDE.md).
Continua dalla fase indicata in STATE.json: modifiche minime e atomiche, poi 'git diff > .omega/drafts/latest.diff'.
Per l'audit esegui ~/.claude/omega/audit.sh <iterazione> (userà un provider diverso da te dove possibile).
Aggiorna STATE.json e DECISIONS.log a ogni transizione. Non committare senza che l'utente lo confermi."
