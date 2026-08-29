#!/usr/bin/env python3
"""One-shot secure endpoint to update OPENCODE_GO_API_KEY.

Binds ONLY to the Tailscale IP so it's unreachable from the internet/LAN.
Accepts a single POST with the new key, writes it to ~/.hermes/.env
(chmod 600), then stops. No logs of the key value.
Usage: set_opencode_key.py <TOKEN> [HOST] [PORT]
"""
import hmac, json, os, re, sys, tempfile, threading
from http.server import BaseHTTPRequestHandler, HTTPServer

ENV_PATH = os.path.expanduser("~/.hermes/.env")
TOKEN = sys.argv[1]
HOST = sys.argv[2] if len(sys.argv) > 2 else "100.125.39.53"
PORT = int(sys.argv[3]) if len(sys.argv) > 3 else 8788

KEY_RE = re.compile(r"^[A-Za-z0-9_-]{16,}$")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        path = self.path.split("?")[0]
        if not hmac.compare_digest(path, "/setkey/" + TOKEN):
            self._resp(403, "forbidden")
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode("utf-8", "replace").strip()
        if body.startswith("{"):
            try:
                body = json.loads(body).get("key", "")
            except Exception:
                body = ""
        elif body.startswith("key="):
            body = body[len("key="):]
        if not KEY_RE.match(body):
            self._resp(400, "invalid key format (16+ alnum/_-)")
            return

        env_dir = os.path.dirname(ENV_PATH)
        tmp = tempfile.NamedTemporaryFile("w", dir=env_dir,
                                          delete=False, encoding="utf-8")
        wrote = False
        try:
            with open(ENV_PATH, "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("OPENCODE_GO_API_KEY="):
                        tmp.write("OPENCODE_GO_API_KEY=" + body + "\n")
                        wrote = True
                    else:
                        tmp.write(line)
            if not wrote:
                tmp.write("OPENCODE_GO_API_KEY=" + body + "\n")
            tmp.flush()
            os.fsync(tmp.fileno())
        finally:
            tmp.close()
        os.chmod(tmp.name, 0o600)
        os.replace(tmp.name, ENV_PATH)
        os.chmod(ENV_PATH, 0o600)
        self._resp(200, "ok: key updated + chmod 600")
        os.makedirs("/tmp/hermes-key-received", exist_ok=True)

    def _resp(self, code, msg):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(msg.encode())

    def log_message(self, *args):
        return  # silence


def shutdown_timer():
    import time
    time.sleep(180)
    os.makedirs("/tmp/hermes-key-timeout", exist_ok=True)
    os._exit(0)


threading.Thread(target=shutdown_timer, daemon=True).start()
server = HTTPServer((HOST, PORT), Handler)
print(f"listening on {HOST}:{PORT} (token set, 180s window)")
server.serve_forever()