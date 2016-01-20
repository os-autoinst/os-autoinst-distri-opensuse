#!/bin/bash
# load modules
for pkg in $(rpm -qa \*-kmp-$1); do
  for mod in $(rpm -ql $pkg | grep '\.ko$'); do
    modname=$(basename $mod .ko)
    modprobe -v $modname
  done
done
