#!/bin/zsh
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG="$CODEX_HOME/config.toml"

if [[ ! -f "$CONFIG" ]]; then
  echo "Codex config not found: $CONFIG"
  exit 1
fi

if rg -n "\[mcp_servers\.xcode\]" "$CONFIG" >/dev/null 2>&1; then
  echo "xcode MCP section already exists in $CONFIG"
  exit 0
fi

cat >> "$CONFIG" <<'TOML'

[mcp_servers.xcode]
command = "npx"
args = ["-y", "xcodebuildmcp"]
TOML

echo "Added [mcp_servers.xcode] to $CONFIG"
echo "Note: first launch needs network to fetch the npm package."
echo "Restart Codex app to load the new MCP server."
