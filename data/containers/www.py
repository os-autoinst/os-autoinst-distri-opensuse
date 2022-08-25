#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Summary: Simple http server replying a static page with CONTENT
#          By default it listens on *:80

from http.server import HTTPServer, BaseHTTPRequestHandler
import os

# Content of the static http page
CONTENT = "<html>The test shall pass</html>"


class TestPassRequestHandler(BaseHTTPRequestHandler):
    """
    Actual webserver request handler. It returns CONTENT on a GET request
    """

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(CONTENT.encode("UTF-8"))
    def log_request(self, format, *args):
        return


# Main program routine: Setup and run the webserver
if __name__ == "__main__":
    # If defined, take the PORT and ADDR environment variables
    port, addr = int(os.environ.get("PORT", 80)), os.environ.get("ADDR", "0.0.0.0")
    print("http serving on %s:%d" % (addr, port))
    httpd = HTTPServer((addr, port), TestPassRequestHandler)
    httpd.serve_forever()
