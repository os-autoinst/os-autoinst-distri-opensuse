#!/usr/bin/env python3
# SPDX-License-Identifier: FSFAP
# Copyright 2026 SUSE LLC
"""Serve one canned reply over the part of the OpenAI API that opencode uses.

The test needs a model endpoint that is deterministic, offline and free, so the
assertions describe opencode rather than whatever a real model felt like saying.
Covers model listing and chat completions, streamed as Server-Sent Events and
returned whole: opencode's openai-compatible provider streams by default and
asks for a usage chunk, so both paths and the trailing usage chunk are here.

Usage: stub_server.py [--port N] [--reply TEXT] [--log PATH]
"""

import argparse
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

REPLY = "OPENQA_STUB_OK"
MODEL = "stub-model"
MAX_BODY = 1 << 20


def _chunk(delta=None, finish=None, usage=None):
    body = {
        "id": "chatcmpl-stub",
        "object": "chat.completion.chunk",
        "created": 0,
        "model": MODEL,
        "choices": [] if usage else [{"index": 0, "delta": delta or {}, "finish_reason": finish}],
    }
    if usage:
        body["usage"] = usage
    return f"data: {json.dumps(body)}\n\n".encode()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        self.server.logfile.write(f"{self.address_string()} - {fmt % args}\n")
        self.server.logfile.flush()

    def _send(self, code, payload, ctype="application/json"):
        raw = payload if isinstance(payload, bytes) else json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path.rstrip("/").endswith("/models"):
            self._send(
                200,
                {
                    "object": "list",
                    "data": [{"id": MODEL, "object": "model", "created": 0, "owned_by": "stub"}],
                },
            )
            return
        self._send(404, {"error": {"message": "not found", "type": "invalid_request_error"}})

    def do_POST(self):
        if not self.path.rstrip("/").endswith("/chat/completions"):
            self._send(404, {"error": {"message": "not found", "type": "invalid_request_error"}})
            return
        length = min(int(self.headers.get("Content-Length") or 0), MAX_BODY)
        try:
            request = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            request = {}
        usage = {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}

        if not request.get("stream"):
            self._send(
                200,
                {
                    "id": "chatcmpl-stub",
                    "object": "chat.completion",
                    "created": 0,
                    "model": MODEL,
                    "choices": [
                        {
                            "index": 0,
                            "message": {"role": "assistant", "content": self.server.reply},
                            "finish_reason": "stop",
                        }
                    ],
                    "usage": usage,
                },
            )
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        for part in (
            _chunk(delta={"role": "assistant", "content": ""}),
            _chunk(delta={"content": self.server.reply}),
            _chunk(delta={}, finish="stop"),
            _chunk(usage=usage),
            b"data: [DONE]\n\n",
        ):
            self.wfile.write(part)
            self.wfile.flush()
        self.close_connection = True


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--reply", default=REPLY)
    parser.add_argument("--log", default="-")
    args = parser.parse_args(argv)

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.reply = args.reply
    server.logfile = sys.stderr if args.log == "-" else open(args.log, "a", buffering=1)
    server.logfile.write(f"stub listening on 127.0.0.1:{args.port}, reply {args.reply!r}\n")
    server.logfile.flush()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
