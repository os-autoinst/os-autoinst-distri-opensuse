#!/bin/sh
# Package dep: python3-kasa

set -ex

echo "Powering OFF"

# Check number of args
if [ "$#" -ne 1 ]; then
    echo "Please provide IP or hostname of the plug as argument"
    exit 1;
fi

# Get IP/hostname from arg
device=$1

/usr/bin/kasa --type plug --host $device off
/usr/bin/kasa --type plug --host $device led 0
