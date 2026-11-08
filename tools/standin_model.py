#!/usr/bin/env python3
"""Local stand-in for a chat-completion endpoint.

It binds to 127.0.0.1, speaks the same JSON shape the callers
already parse, and does not use the network or a real key.
The path is /<mode>/<which>:

  good     a fixed reply the checker accepts
  wrong    a well-formed reply the checker rejects
  broken   a body with no assistant content string
  timeout  the request is recorded, then the handler waits

Each request is appended to <log-dir>/<mode>-<which>.http so
the Ada check can read what was sent.
"""

from __future__ import annotations

import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOST = "127.0.0.1"
TIMEOUT_SECONDS = 45
LOCK = threading.Lock()

GOOD = {
    "recurse": "index 0\nminus-one 1\ncurrent 1\n",
    "traces": "rate-1-train-200",
    "harness": "rate-1-train-200",
}
WRONG = {
    "recurse": "index 0\nminus-one 1\ncurrent 9\n",
    "traces": "invert-output",
    "harness": "invert-output",
}


def chat_body(content: str) -> bytes:
    payload = {
        "choices": [
            {"message": {"role": "assistant", "content": content}}
        ]
    }
    return json.dumps(payload, ensure_ascii=True).encode("utf-8")


BROKEN = b'{"choices":[{"message":{"role":"assistant"}}]}'


def one_line(text: str) -> str:
    return text.replace("\r", " ").replace("\n", " ")


class Handler(BaseHTTPRequestHandler):
    log_dir = "."

    def log_message(self, fmt: str, *args) -> None:
        return

    def _send(self, code: int, body: bytes, content_type: str) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        if path == "/health":
            self._send(200, b"ok\n", "text/plain")
            return
        self._send(404, b"not found\n", "text/plain")

    def do_POST(self) -> None:  # noqa: N802
        path = self.path.split("?", 1)[0]
        parts = [piece for piece in path.split("/") if piece]
        mode = parts[0] if parts else ""
        which = parts[1] if len(parts) > 1 else ""
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length > 0 else b""
        try:
            body = raw.decode("utf-8")
        except UnicodeDecodeError:
            body = ""
        auth = self.headers.get("Authorization", "")
        ctype = self.headers.get("Content-Type", "")
        record = (
            f"request POST {path}\n"
            f"authorization: {one_line(auth)}\n"
            f"content-type: {one_line(ctype)}\n"
            f"body {one_line(body)}\n"
        )
        if mode in {"good", "wrong", "broken", "timeout"} and which in {
            "recurse",
            "traces",
            "harness",
        }:
            dest = f"{self.log_dir}/{mode}-{which}.http"
            with LOCK:
                with open(dest, "a", encoding="utf-8") as handle:
                    handle.write(record)
        if mode == "timeout":
            time.sleep(TIMEOUT_SECONDS)
            self._send(200, chat_body(""), "application/json")
            return
        if mode == "broken":
            self._send(200, BROKEN, "application/json")
            return
        table = GOOD if mode == "good" else WRONG if mode == "wrong" else None
        if table is None or which not in table:
            self._send(404, b"not found\n", "text/plain")
            return
        self._send(200, chat_body(table[which]), "application/json")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: standin_model.py PORT LOG_DIR", file=sys.stderr)
        return 2
    port = int(sys.argv[1])
    Handler.log_dir = sys.argv[2]
    server = ThreadingHTTPServer((HOST, port), Handler)
    print(f"stand-in {HOST}:{port}", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
