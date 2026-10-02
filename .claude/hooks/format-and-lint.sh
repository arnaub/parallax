#!/bin/bash
# PostToolUse hook: formats and lints the file just edited/written, but
# only when it's an Elixir source file.
set -euo pipefail

input="$(cat)"
file_path="$(python3 -c 'import json, sys; print(json.loads(sys.argv[1]).get("tool_input", {}).get("file_path", ""))' "$input")"
cwd="$(python3 -c 'import json, sys; print(json.loads(sys.argv[1]).get("cwd", ""))' "$input")"

if [[ -z "$file_path" || ! "$file_path" =~ \.(ex|exs)$ ]]; then
  exit 0
fi

cd "${cwd:-.}"

mix format "$file_path"
mix credo "$file_path"
