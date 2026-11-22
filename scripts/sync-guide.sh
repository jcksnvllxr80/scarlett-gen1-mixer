#!/bin/bash
# Copies docs/user-guide.md into the app (shown by Help ▸ User Guide). A unit test checks they match.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cp "$ROOT/docs/user-guide.md" "$ROOT/ScarlettGen1Mixer/ScarlettGen1Mixer/Help/user-guide.md"
echo "Synced user guide into the app."
