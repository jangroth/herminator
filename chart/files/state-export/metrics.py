"""Serve the export's metrics file at /metrics; empty until the first run finishes.

Usage: metrics.py FILE PORT
"""
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

FILE = sys.argv[1]
PORT = int(sys.argv[2])


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.split("?", 1)[0] != "/metrics":
            self.send_error(404)
            return
        try:
            with open(FILE, "rb") as f:
                body = f.read()
        except FileNotFoundError:
            body = b""
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


HTTPServer(("", PORT), Handler).serve_forever()
