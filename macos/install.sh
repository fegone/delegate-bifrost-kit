#!/usr/bin/env bash
# macOS (Apple Silicon) installer for the delegate. It does NOT start Bifrost, does NOT run
# `claude mcp add` and never reads your keys: it clones the delegate at the pinned commit,
# builds a venv, and prints the `claude mcp add` line for you to paste.
#   DEST=/some/dir       where delegate/ and .venv/ go (default: the kit folder)
#   BIFROST_PORT=4010    port used in the printed command
set -euo pipefail

SHA=e43f506078fd95de82bbd3613aea0c789cefb05b
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DEST:-$KIT}"
PORT="${BIFROST_PORT:-4010}"

[ "$(uname -s)" = "Darwin" ] || { echo "This script is for macOS. On Windows use WSL2 (wsl/README.md)." >&2; exit 1; }
command -v git >/dev/null || { echo "Missing git. Run: brew install git" >&2; exit 1; }
command -v claude >/dev/null || echo "Warning: 'claude' not found. Install Claude Code before running the printed command." >&2

if command -v node >/dev/null; then
  [ "$(node -v | sed 's/^v//; s/\..*//')" -ge 20 ] || { echo "Node must be 20+. Run: brew install node" >&2; exit 1; }
else
  echo "Missing node. Run: brew install node" >&2; exit 1
fi

PY=""
for c in python3.13 python3.12 python3.11 python3 python3.14; do
  if command -v "$c" >/dev/null && "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
    PY="$(command -v "$c")"; break
  fi
done
[ -n "$PY" ] || { echo "Need Python 3.11+. Run: brew install python@3.12" >&2; exit 1; }

mkdir -p "$DEST"
if [ ! -d "$DEST/delegate/.git" ]; then
  git clone -q https://github.com/fegone/claude-code-delegate-local.git "$DEST/delegate"
fi
git -C "$DEST/delegate" fetch -q origin || true
git -C "$DEST/delegate" checkout -q "$SHA"

[ -x "$DEST/.venv/bin/python" ] || "$PY" -m venv "$DEST/.venv"
"$DEST/.venv/bin/pip" install -q "fastmcp>=3.4.4" "httpx>=0.28.1"

echo "Delegate at $(git -C "$DEST/delegate" rev-parse --short HEAD), venv ready."
echo
echo "Start Bifrost (see macos/README.md), then paste this and restart Claude Code:"
echo
echo "claude mcp add delegate-local --scope user \\"
echo "  --env DELEGATE_GATEWAY=bifrost \\"
echo "  --env DELEGATE_BIFROST_URL=http://127.0.0.1:$PORT \\"
echo "  --env DELEGATE_BIFROST_VK_LOCAL= \\"
echo "  --env DELEGATE_BIFROST_VK_CODE= \\"
echo "  --env DELEGATE_LOCAL_MODEL=glm-coding-plan \\"
echo "  -- \"$DEST/.venv/bin/python\" \"$DEST/delegate/server.py\""
