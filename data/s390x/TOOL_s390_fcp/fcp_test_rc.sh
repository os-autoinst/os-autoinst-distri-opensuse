# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

for i in `ls lib/*.sh`; do source $i || exit 8; done

source lib/env.sh || exit 1

init_tests

start_section 0 "TOOL:lszfcp test"

dmesg -C

adapter=$1
wwpn=$2
lun=$3


echo "attach device ${adapter} via vmcp"
if [ ! -d /sys/bus/ccw/drivers/zfcp/${adapter} ]
then
                isVM
                if [ $? == 0 ]
                then
                        if [ load_vmcp != 0 ]
                        then
                                modprobe vmcp
                        fi
                        temp=`echo ${adapter} | awk -F. '{print $3}'`

                        echo "Adapter "$temp
                        echo "Setting device ${adapter} online"
                        assert_exec 0 vmcp attach $temp to \\*
                        sleep 3
                        cleanup_scsi_reqd=1
                fi
fi

if ! chccwdev -e $adapter; then
	echo "Current CHPID list";
	lschp;

	echo;
	echo "CHPID not enabled?";
	echo "DEV:  ${adapter}";
	echo "WWPN: ${wwpn}";
	echo "LUN:  ${lun}";
	assert_fail 1 0 "Could not find device '${adapter}'";
fi

udevadm settle
pth=$(pwd)
assert_exec 0 cd /sys/bus/ccw/drivers/zfcp/$adapter/$wwpn
echo $lun > unit_add

echo "Current CHPID list";
assert_exec 0 lschp

assert_exec 0 "lscss --vpm | grep \"$adapter\"";

cd $pth

assert_exec 0 ./lszfcp_rc.sh $1 $2 $3
sleep 2

assert_exec 0 ./lsscsi_rc.sh $1 $2 $3
sleep 2

assert_exec 0 ./zfcpdbf_rc.sh $1 $2 $3
sleep 2

assert_exec 0 ./scsi_logging_level_rc.sh $1 $2 $3
sleep 2

assert_exec 0 ./lsluns_rc.sh $1 $2 $3
sleep 2


assert_exec 0 cd /sys/bus/ccw/drivers/zfcp/$adapter/$wwpn

echo "removing Scsi Device From the test system"

echo ${lun} > /sys/bus/ccw/drivers/zfcp/${adapter}/${wwpn}/unit_remove
sleep 2
assert_exec 0 chccwdev -d $adapter
isVM
if [ $? == 0 ]
then
        if [ load_vmcp != 0 ]
        then
               modprobe vmcp
        fi
        temp=`echo ${adapter} | awk -F. '{print $3}'`
        echo "Adapter "$temp
        echo "Setting device ${adapter} offline"
        assert_exec 0 vmcp det $temp
        sleep 3

fi





end_section 0
show_test_results
exit
