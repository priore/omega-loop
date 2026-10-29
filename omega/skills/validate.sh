#!/usr/bin/env bash
# Extension dispatcher: validate.sh <file...>. Extension without a validator = skip. Exit 1 if any fails.
D="$(cd "$(dirname "$0")" && pwd)"; rc=0
# ng_validator is active for repos in ~/.claude/omega/projects.json ({"~/path/to/repo": {"ng": true}}, ~ expanded) or with OMEGA_NG=1
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
NG=$(python3 -c 'import json,os,sys;c=json.load(open(sys.argv[1]));print(int(any(os.path.expanduser(k)==sys.argv[2] and v.get("ng") for k,v in c.items())))' "$D/../projects.json" "$ROOT" 2>/dev/null || echo 0)
[ "${OMEGA_NG:-0}" = 1 ] && NG=1
for f in "$@"; do
  case "$f" in
    *.scad)  python3 "$D/scad_validator.py" "$f" || rc=1 ;;
    *.swift) bash "$D/swift_validator.sh" "$f" || rc=1 ;;
    *.csx|*.cs) command -v dotnet-script >/dev/null && { dotnet-script "$D/cs_validator.csx" -- "$f" || rc=1; } || echo "[skip] dotnet-script not found: $f" ;;
    *.js|*.html) [ "$NG" = 1 ] && { node "$D/ng_validator.js" "$f" || rc=1; } ;;
  esac
done
exit $rc
