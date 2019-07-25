#!/bin/sh -e

if [ $(id -u) -ne 0 ]; then
    echo "Not running as root!"
    exit 1
fi

zypper --non-interactive refresh
