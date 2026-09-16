#!/usr/bin/env bash
# Run gdlint over the project — the same paths CI lints (see .github/workflows/ci.yml).
# Install the linter once with:  pipx install gdtoolkit
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v gdlint >/dev/null 2>&1; then
	echo "gdlint not found. Install it with:  pipx install gdtoolkit" >&2
	exit 1
fi

exec gdlint sim presentation main test
