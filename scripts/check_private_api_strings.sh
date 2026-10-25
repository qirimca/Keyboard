#!/usr/bin/env bash
# Bounded regression scan, not proof of public-API compliance. See Python --help.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -eq 0 ]]; then
  set -- QTatar
fi
exec python3 "$SCRIPT_DIR/check_private_apis.py" "$@"
