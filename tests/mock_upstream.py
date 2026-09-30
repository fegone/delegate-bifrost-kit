#!/usr/bin/env python3
"""Tiny fake LLM provider for the kit's end-to-end test. No real keys, no network.

Speaks the two shapes the kit's providers use and always answers with plain text
(no tool calls), so the delegate finishes in one turn:
  * Anthropic  POST .../v1/messages          (JSON or SSE)
  * OpenAI     POST .../chat/completions     (JSON or SSE)
Every request is appended as one JSON line to the log file (path, model, auth
header NAMES only, never their values).
"""
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]); LOG = sys.argv[2]
ANSWER = "MOCK-OK"


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _send(self, code, ctype, body: bytes):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        raw = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        try:
            req = json.loads(raw or b"{}")
        except ValueError:
            req = {}
        path = self.path.split("?")[0]
        with open(LOG, "a") as f:
            f.write(json.dumps({
                "path": path, "model": req.get("model"), "stream": bool(req.get("stream")),
                "auth_headers": sorted(h for h in ("x-api-key", "authorization") if self.headers.get(h)),
            }) + "\n")
        stream = bool(req.get("stream"))
        if path.endswith("/v1/messages"):
            self._anthropic(req, stream)
        elif path.endswith("/chat/completions"):
            self._openai(req, stream)
        else:
            self._send(404, "application/json", b'{"error":"mock: unknown path"}')

    def _anthropic(self, req, stream):
        m = req.get("model", "mock")
        usage = {"input_tokens": 5, "output_tokens": 3}
        if not stream:
            body = {"id": "msg_mock", "type": "message", "role": "assistant", "model": m,
                    "content": [{"type": "text", "text": ANSWER}],
                    "stop_reason": "end_turn", "stop_sequence": None, "usage": usage}
            return self._send(200, "application/json", json.dumps(body).encode())
        ev = [
            ("message_start", {"type": "message_start", "message": {
                "id": "msg_mock", "type": "message", "role": "assistant", "model": m,
                "content": [], "stop_reason": None, "usage": {"input_tokens": 5, "output_tokens": 0}}}),
            ("content_block_start", {"type": "content_block_start", "index": 0,
                                     "content_block": {"type": "text", "text": ""}}),
            ("content_block_delta", {"type": "content_block_delta", "index": 0,
                                     "delta": {"type": "text_delta", "text": ANSWER}}),
            ("content_block_stop", {"type": "content_block_stop", "index": 0}),
            ("message_delta", {"type": "message_delta", "delta": {"stop_reason": "end_turn", "stop_sequence": None},
                               "usage": {"output_tokens": 3}}),
            ("message_stop", {"type": "message_stop"}),
        ]
        out = "".join(f"event: {n}\ndata: {json.dumps(d)}\n\n" for n, d in ev)
        self._send(200, "text/event-stream", out.encode())

    def _openai(self, req, stream):
        m = req.get("model", "mock")
        if not stream:
            body = {"id": "chatcmpl-mock", "object": "chat.completion", "created": 1, "model": m,
                    "choices": [{"index": 0, "finish_reason": "stop",
                                 "message": {"role": "assistant", "content": ANSWER}}],
                    "usage": {"prompt_tokens": 5, "completion_tokens": 3, "total_tokens": 8}}
            return self._send(200, "application/json", json.dumps(body).encode())
        base = {"id": "chatcmpl-mock", "object": "chat.completion.chunk", "created": 1, "model": m}
        chunks = [
            {**base, "choices": [{"index": 0, "delta": {"role": "assistant", "content": ANSWER}, "finish_reason": None}]},
            {**base, "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]},
            {**base, "choices": [], "usage": {"prompt_tokens": 5, "completion_tokens": 3, "total_tokens": 8}},
        ]
        out = "".join(f"data: {json.dumps(c)}\n\n" for c in chunks) + "data: [DONE]\n\n"
        self._send(200, "text/event-stream", out.encode())


ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
