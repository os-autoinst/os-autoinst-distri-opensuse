#!/usr/bin/env python3
##
## Simple Flask test program (see https://flask.palletsprojects.com/en/2.0.x/quickstart/)
## Serve 'index.html' from the `templates` directory
##
## Usage: python3 app.py
## Bind to port 80 or to the PORT environment variable, if set
from flask import Flask, render_template
import os, sys, ssl

app = Flask(__name__)

@app.route("/")
def index():
    return render_template("index.html")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 80)))
