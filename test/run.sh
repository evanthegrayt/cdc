#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v bats >/dev/null 2>&1; then
    echo "bats is required to run the test suite." >&2
    echo "Install bats-core, then run: ./test/run.sh" >&2
    exit 127
fi

bats test
