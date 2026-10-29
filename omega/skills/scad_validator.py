#!/usr/bin/env python3
import sys, re

def validate_scad(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    errors = []
    if "difference()" in content and not re.search(r'difference\s*\(\)\s*\{', content):
        errors.append("Invalid difference() structure. Format must be: difference() { main(); subtractions(); }")
    if "difference()" in content and "+ 0.2" not in content and "+0.2" not in content:
        errors.append("Subtractions inside difference() must use height padding (e.g., 'h + 0.2') to prevent ghosting.")
    if "minkowski" in content:
        errors.append("Avoid 'minkowski()' due to performance degradation. Use chamfered/filleted primitives.")
    if errors:
        print("\n".join(f"[SCAD ERROR] {e}" for e in errors))
        sys.exit(1)
    print("[SCAD VALIDATION PASSED]")

if __name__ == "__main__":
    validate_scad(sys.argv[1])
