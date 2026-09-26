"""Stub upstream: answers every request with the headers nginx sent it.

The body is one "name: value" line per received header, in arrival order, so
tests can assert on what the proxy forwarded (duplicates included).
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Echo(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _reply(self):
        body = "".join(f"{k}: {v}\n" for k, v in self.headers.items()).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = _reply

    def log_message(self, *args):
        pass


ThreadingHTTPServer(("0.0.0.0", 8080), Echo).serve_forever()
