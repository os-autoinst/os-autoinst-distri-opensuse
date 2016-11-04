#!/bin/bash
# load modules
for pkg in $(rpm -qa \*-kmp-rt); do
  for mod in $(rpm -ql $pkg | grep '\.ko$'); do
    modname=$(basename $mod .ko)
    modprobe $modname || fail=1
  done
done
if [ $fail ] ; then exit 1 ; fi
