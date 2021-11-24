# Copyright 2018 IBM Corp.
# SPDX-License-Identifier: FSFAP


#!/bin/bash
TESTDIR=$(dirname $0)

ccwdev_list_create()
{
dascount=`lsdasd | wc -l`
dascount=$((dascount-2))

for i in $(seq 1 1 $dascount)
do
 n=$((i+2))
 tempdas=`lsdasd | awk '{ print $1 }' | sed -n "$n"p |cut -d "." -f3`
 cat /etc/zipl.conf | grep -i $tempdas
   if [ $? -ne 0 ]; then
    echo $tempdas >> dasd.txt
   fi
done

bcount=`ls /sys/bus/ccw/drivers/zfcp/ | grep -i "0.0" | wc -l`
for i in $(seq 1 $bcount)
 do
 bus=`ls /sys/bus/ccw/drivers/zfcp | grep "0.0" | sed -n "$i"p | cut -d "." -f3`
   pcount=`ls /sys/bus/ccw/drivers/zfcp/0.0.$bus | grep "0x" | wc -l`
   if [ $pcount -ge 1 ]; then
         echo "$bus" >> zfcpall.cfg
       fi
  done
if [ -e zfcpall.cfg ] ; then
   cat zfcpall.cfg | sort | uniq >> zfcp.cfg
fi

if [ -e zfcpall.cfg ] ; then
rm -rf zfcpall.cfg
fi
}
ccwdev_list_create
