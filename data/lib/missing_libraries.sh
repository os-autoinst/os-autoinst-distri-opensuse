#!/bin/sh

IFS=:
for path in $PATH; do
    for bin in $path/*; do
        ldd $bin 2> /dev/null | grep 'not found' && echo -n Affected binary: $bin 'from ' && rpmquery -f $bin
    done
done
