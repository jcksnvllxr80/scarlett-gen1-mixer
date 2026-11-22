#!/bin/bash
# Prints the app's version from ScarlettGen1Mixer/Version.xcconfig, the only place it is set.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
awk -F'=' '/^[[:space:]]*MARKETING_VERSION[[:space:]]*=/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$ROOT/ScarlettGen1Mixer/Version.xcconfig"
