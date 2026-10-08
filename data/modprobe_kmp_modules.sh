#!/bin/bash
# load modules
for pkg in $(rpm -qa \*-kmp-rt); do
  for mod in $(rpm -ql $pkg | grep '\.ko$'); do
    modname=$(basename $mod .ko)
    modprobe $modname &>> /var/log/modprobe.out || fail=1
  done
done
if [ $fail ] ; then exit 1 ; fi
