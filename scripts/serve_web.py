#!/usr/bin/env python3
"""Serves a Flutter web build the way the Cloudflare Worker does.

Unknown paths get index.html (the Worker's "single-page-application"
not-found handling), and the rules in the build's `_headers` file are applied
to every response they match, so a page looked at locally carries the headers
production sends. Only the two rule shapes `web/_headers` uses are read: an
exact path, and a prefix ending in `*`.

    python3 scripts/serve_web.py build/web 8811
"""
import functools
import http.server
import os
import sys


def read_rules(root):
    """The `_headers` file as (pattern, [(name, value)]) pairs, in order."""
    path = os.path.join(root, '_headers')
    rules = []
    if not os.path.exists(path):
        return rules
    with open(path, encoding='utf-8') as handle:
        for raw in handle:
            line = raw.rstrip('\n')
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            if not line[0].isspace():
                rules.append((line.strip(), []))
            elif rules and ':' in line:
                name, value = line.strip().split(':', 1)
                rules[-1][1].append((name.strip(), value.strip()))
    return rules


def matches(pattern, path):
    if pattern.endswith('*'):
        return path.startswith(pattern[:-1])
    return path == pattern


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        '.wasm': 'application/wasm',
        '.mjs': 'text/javascript',
        '.js': 'text/javascript',
    }

    def __init__(self, *args, rules, **kwargs):
        self._rules = rules
        super().__init__(*args, **kwargs)

    def end_headers(self):
        # An error that never reached send_head has only the path as sent.
        path = getattr(self, '_requested', self.path.split('?', 1)[0])
        for pattern, headers in self._rules:
            if matches(pattern, path):
                for name, value in headers:
                    self.send_header(name, value)
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def send_head(self):
        path = self.path.split('?', 1)[0]
        # The Worker matches rules against the path that was asked for, not
        # the index.html a fallback answers with. Each handler serves one
        # request (HTTP/1.0), so this cannot carry over to the next.
        self._requested = path
        # The Worker never serves `_headers` itself, and neither does this.
        # A directory is no asset to it either, so `/assets` gets index.html.
        if path == '/_headers' or not os.path.isfile(self.translate_path(path)):
            self.path = '/index.html'
        return super().send_head()


def main():
    root, port = sys.argv[1], int(sys.argv[2])
    handler = functools.partial(Handler, directory=root, rules=read_rules(root))
    server = http.server.ThreadingHTTPServer(('127.0.0.1', port), handler)
    print(f'Serving {root} on http://127.0.0.1:{port}', flush=True)
    server.serve_forever()


if __name__ == '__main__':
    main()
