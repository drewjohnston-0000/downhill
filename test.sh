#!/usr/bin/env bash
# Run the project's gdUnit4 unit tests headless.
#   ./test.sh                              run every *_test.gd (excluding addons/)
#   ./test.sh test/rider_simulation_test.gd  run specific suite(s)
# Override the Godot binary with GODOT_BIN if it lives elsewhere.
set -euo pipefail
cd "$(dirname "$0")"

GODOT_BIN="${GODOT_BIN:-/Applications/Godot_4.8.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT_BIN" ]; then
	echo "Godot binary not found at: $GODOT_BIN" >&2
	echo "Set GODOT_BIN to your Godot executable." >&2
	exit 1
fi

args=()
if [ $# -gt 0 ]; then
	for t in "$@"; do args+=(-a "res://${t#res://}"); done
else
	while IFS= read -r f; do
		args+=(-a "res://${f#./}")
	done < <(find . -name '*_test.gd' -not -path './addons/*' -not -path './.godot/*' | sort)
fi

if [ ${#args[@]} -eq 0 ]; then
	echo "No *_test.gd files found." >&2
	exit 1
fi

exec "$GODOT_BIN" --headless --path . \
	-s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode "${args[@]}"
