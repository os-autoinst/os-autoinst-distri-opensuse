#!/bin/sh

set -ex

echo "Powering ON"

/usr/sbin/uhubctl -a 1 "$@"
