#!/bin/bash

set -e -x

grep -P "10.226.154.19\tnew.entry.de h999uz" /etc/hosts && echo "AUTOYAST OK"
