#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <url> [--staff] (use a disposable database)" >&2
  exit 2
fi
exec python3 "$(dirname "$0")/smoke-test.py" "$@"
