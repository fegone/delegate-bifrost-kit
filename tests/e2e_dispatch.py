"""Dispatch one tiny task per model through the delegate's MCP tool function.

Usage: python e2e_dispatch.py <delegate_dir> <workdir> <model> [<model> ...]
Env (same as the kit's `claude mcp add`): DELEGATE_GATEWAY=bifrost,
DELEGATE_BIFROST_URL, empty DELEGATE_BIFROST_VK_*.  Exit 0 only if every model
returned success and the mock's answer text.
"""
import asyncio, importlib.util, json, sys

delegate_dir, workdir, *models = sys.argv[1:]
spec = importlib.util.spec_from_file_location("delegate_server", f"{delegate_dir}/server.py")
srv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(srv)
tool = srv.delegate_to_local_agent
fn = getattr(tool, "fn", tool)  # FastMCP may wrap the function

async def main() -> int:
    bad = 0
    for m in models:  # one event loop: the delegate keeps a shared HTTP client
        r = await fn(agent_name="kit-smoke", task="Reply with one word.",
                     workdir=workdir, max_turns=2, model=m)
        text = json.dumps(r, ensure_ascii=False)
        ok = bool(r.get("success")) and "MOCK-OK" in text
        print(f"{'PASS' if ok else 'FAIL'} model={m} success={r.get('success')} "
              f"model_used={r.get('model_used', r.get('model'))} error={r.get('error')}")
        bad += 0 if ok else 1
    return 1 if bad else 0


sys.exit(asyncio.run(main()))
