#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/muttan-model-checks.XXXXXX")"
trap 'rm -r "$CHECK_DIR"' EXIT
swiftc \
  "$ROOT_DIR/muttan/Features/Chords/Chord.swift" \
  "$ROOT_DIR/muttan/Features/Practice/PitchDetector.swift" \
  "$ROOT_DIR/muttan/Features/Practice/TunerSignal.swift" \
  "$ROOT_DIR/tests/ModelChecks/main.swift" \
  -o "$CHECK_DIR/check-models"
"$CHECK_DIR/check-models" "$ROOT_DIR/muttan/Features/Chords/chords.json"
python3 "$ROOT_DIR/scripts/validate-chords.py"
