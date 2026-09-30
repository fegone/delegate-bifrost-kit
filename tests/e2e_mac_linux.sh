#!/usr/bin/env bash
# End-to-end test, no real keys and no provider calls:
#   delegate (pinned sha) -> upstream Bifrost (127.0.0.1) -> mock provider (127.0.0.1)
# Dispatches one tiny task with glm-coding-plan (Anthropic-shape upstream) and one with
# deepseek-v4-flash (OpenAI-shape upstream) and checks both reach the mock with the
# provider model id from bifrost/config.example.json.
#
# Needs: bash, python3.11+, node 20+ (npx), git, curl.  Internet only to fetch the npm
# package (and the delegate if DELEGATE_SRC is not set).
#   DELEGATE_SRC=/path/to/local/clone  use a local clone instead of cloning from GitHub
#   BIFROST_PORT / MOCK_PORT           default 14010 / 14011
set -euo pipefail

SHA=916fff06243b4f7b273a6c893ffa56c31c71745a
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIFROST_PORT="${BIFROST_PORT:-14010}"
MOCK_PORT="${MOCK_PORT:-14011}"
PY="${PYTHON:-python3}"
T="$(mktemp -d)"
PIDS=()

cleanup() {
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
  # npx spawns the real binary as a child of the pid we saved
  pkill -f "app-dir $T/app" 2>/dev/null || true
  rm -rf "$T"
}
trap cleanup EXIT

grep -q "$SHA" "$KIT/windows/install.ps1" "$KIT/wsl/README.md" "$KIT/README.md" \
  || { echo "FAIL: pinned sha out of sync in the kit"; exit 1; }

echo "== delegate @ ${SHA:0:7}"
if [ -n "${DELEGATE_SRC:-}" ]; then
  mkdir -p "$T/delegate"
  git -C "$DELEGATE_SRC" archive "$SHA" | tar -x -C "$T/delegate"
else
  git clone -q https://github.com/fegone/claude-code-delegate-local.git "$T/delegate"
  git -C "$T/delegate" checkout -q "$SHA"
fi
"$PY" -m venv "$T/venv"
"$T/venv/bin/pip" install -q "fastmcp>=3.4.4" "httpx>=0.28.1"

echo "== mock provider :$MOCK_PORT"
: > "$T/mock.log"
"$PY" "$KIT/tests/mock_upstream.py" "$MOCK_PORT" "$T/mock.log" & PIDS+=($!)

echo "== bifrost :$BIFROST_PORT (config = example with base_urls pointed at the mock)"
mkdir -p "$T/app"
KIT_CFG="$KIT/bifrost/config.example.json" OUT="$T/app/config.json" M="http://127.0.0.1:$MOCK_PORT" \
"$PY" - <<'PYEOF'
import json, os
c = json.load(open(os.environ["KIT_CFG"]))
m = os.environ["M"]
p = c["providers"]
p["anthropic"]["network_config"]["base_url"] = m + "/anthropic"
p["deepseek"]["network_config"]["base_url"] = m + "/deepseek"
p["generic-openai"]["network_config"]["base_url"] = m + "/generic/v1"
json.dump(c, open(os.environ["OUT"], "w"), indent=1)
PYEOF
ZAI_API_KEY=dummy-zai DEEPSEEK_API_KEY=dummy-deepseek GENERIC_OPENAI_API_KEY=dummy-generic \
  npx -y @maximhq/bifrost@1.6.3 -host 127.0.0.1 -port "$BIFROST_PORT" -app-dir "$T/app" \
  > "$T/bifrost.log" 2>&1 & PIDS+=($!)

for _ in $(seq 1 120); do
  curl -s -o /dev/null -m 2 "http://127.0.0.1:$BIFROST_PORT/" && break
  sleep 1
done
curl -s -o /dev/null -m 2 "http://127.0.0.1:$BIFROST_PORT/" \
  || { echo "FAIL: bifrost did not start"; tail -20 "$T/bifrost.log"; exit 1; }

echo "== dispatch through the delegate"
mkdir -p "$T/work/.claude/agents"
printf -- '---\nname: kit-smoke\ndescription: smoke test agent\n---\nYou are a test agent. Answer briefly.\n' \
  > "$T/work/.claude/agents/kit-smoke.md"
# Same env the installers register with `claude mcp add` (empty VKs: governance is off).
DELEGATE_GATEWAY=bifrost DELEGATE_BIFROST_URL="http://127.0.0.1:$BIFROST_PORT" \
DELEGATE_BIFROST_VK_LOCAL= DELEGATE_BIFROST_VK_CODE= DELEGATE_LOCAL_MODEL=glm-coding-plan \
  "$T/venv/bin/python" "$KIT/tests/e2e_dispatch.py" "$T/delegate" "$T/work" \
  glm-coding-plan deepseek-v4-flash

echo "== what the mock saw"
cat "$T/mock.log"
grep -q '"path": "/anthropic/v1/messages", "model": "glm-5.3"' "$T/mock.log" \
  || { echo "FAIL: z.ai slot did not reach the mock as /v1/messages + glm-5.3"; exit 1; }
grep -q '"path": "/deepseek/chat/completions", "model": "deepseek-v4-flash"' "$T/mock.log" \
  || { echo "FAIL: deepseek slot did not reach the mock as /chat/completions"; exit 1; }
echo "E2E PASS: glm-coding-plan and deepseek-v4-flash both reached the upstream mock through Bifrost"
