#!/bin/sh
for dev in $(ls /sys/class/net/ | grep -v lo) ;
    do
    if ! grep -q "$1" /sys/class/net/$dev/operstate ; then
        echo "device $dev is not $1"
        exit 1
    fi
done