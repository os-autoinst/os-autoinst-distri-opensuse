#!/bin/sh

set -ex

echo "Powering OFF"

/usr/sbin/uhubctl -a 0 "$@"
