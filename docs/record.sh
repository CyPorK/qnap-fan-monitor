#!/usr/bin/env bash
# Generates demo GIF via VHS.
# Usage: bash docs/record.sh <pve-host>
# Example: bash docs/record.sh <pve-host>

set -euo pipefail

HOST="${1:?Usage: $0 <pve-host>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TAPE=$(mktemp /tmp/demo-XXXXXX.tape)
trap 'rm -f "$TAPE"' EXIT

sed "s/<pve-host>/$HOST/" "$SCRIPT_DIR/demo.tape" > "$TAPE"
vhs "$TAPE"

echo "Done: docs/demo.gif"
