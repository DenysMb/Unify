#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2025 Denys Madureira
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Local TLS-impersonating sidecar for Unify.
# Qt WebEngine's BoringSSL build has a TLS fingerprint that Cloudflare's bot
# detection rejects (cf-mitigated: challenge on CORS preflights). This sidecar
# re-issues requests through curl_cffi with a real browser fingerprint.
# Binds to 127.0.0.1 only and requires a per-session token header.

import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    from curl_cffi import requests as curl_requests
except ImportError:
    print("ERROR=curl_cffi-missing", flush=True)
    sys.exit(1)

TOKEN = os.environ.get("UNIFY_PROXY_TOKEN", "")
IMPERSONATE = os.environ.get("UNIFY_PROXY_IMPERSONATE", "chrome99")

# Single session = single cookie jar. Cookie-based login flows (e.g. Standard
# Notes uses access-control-allow-credentials) depend on cookies being stored
# and resent; the browser's own cookie jar is bypassed on this code path.
# TODO(tls-proxy): per-profile cookie jars for multi-account isolated profiles
SESSION = curl_requests.Session(impersonate=IMPERSONATE)

HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "transfer-encoding",
    "te",
    "trailer",
    "upgrade",
    "proxy-authenticate",
    "proxy-authorization",
    "content-length",
    "content-encoding",
    "host",
}


class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("cf-proxy: " + (fmt % args) + "\n")

    def _respond(self, code, body):
        payload = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def _handle(self):
        if not TOKEN or self.headers.get("X-Unify-Token") != TOKEN:
            return self._respond(403, "forbidden")

        target = self.headers.get("X-Unify-Target-Url", "")
        if not target.startswith("https://"):
            return self._respond(400, "only https targets are allowed")

        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length > 0 else None

        forward_headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in HOP_BY_HOP and not key.lower().startswith("x-unify-")
        }

        try:
            upstream = SESSION.request(
                self.command,
                target,
                headers=forward_headers,
                data=body,
                timeout=30,
                allow_redirects=False,
            )
        except Exception as exc:
            return self._respond(502, "upstream error: %s" % exc)

        sys.stderr.write("cf-proxy: %s %s -> %d\n" % (self.command, target, upstream.status_code))

        payload = upstream.content
        self.send_response(upstream.status_code)
        for key, value in upstream.headers.items():
            if key.lower() not in HOP_BY_HOP:
                self.send_header(key, value)
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    do_GET = _handle
    do_POST = _handle
    do_PUT = _handle
    do_PATCH = _handle
    do_DELETE = _handle
    do_OPTIONS = _handle
    do_HEAD = _handle


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), ProxyHandler)
    print("PORT=%d" % server.server_address[1], flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
