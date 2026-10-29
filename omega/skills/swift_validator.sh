#!/usr/bin/env bash
FILE="$1"
ERRORS=0
if grep -q "DispatchQueue.main" "$FILE"; then
    echo "[SWIFT ERROR] Forbidden 'DispatchQueue.main' found. Use '@MainActor' and native async/await."
    ERRORS=$((ERRORS + 1))
fi
if grep -q "ObservableObject" "$FILE"; then
    echo "[SWIFT ERROR] Forbidden 'ObservableObject' found. Use modern '@Observable' macro."
    ERRORS=$((ERRORS + 1))
fi
if grep -E "(\{.*in)" "$FILE" | grep -v "\[weak self\]" | grep -q "self\."; then
    echo "[SWIFT WARNING] Potential retain cycle detected. Verify explicit '[weak self]' in closure."
fi
[ $ERRORS -gt 0 ] && exit 1
echo "[SWIFT VALIDATION PASSED]"
