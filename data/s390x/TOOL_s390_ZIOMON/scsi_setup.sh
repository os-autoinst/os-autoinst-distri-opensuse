# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

source lib/auxx.sh || exit 1
source lib/env.sh || exit 1

chccwdev_tool_path=$(s390_get_tool_path chccwdev)
fdasd_tool_path=$(s390_get_tool_path fdasd)


function setup_scsi()
{
        echo "Setup scsi device for the test"

        modprobe zfcp

        if [ -d /sys/bus/ccw/drivers/zfcp/$scsi_adapter ]
        then
                is_online=`cat /sys/bus/ccw/drivers/zfcp/$scsi_adapter/online`
                if [ $is_online -eq 1 ]
                then
                        echo "Device $scsi_adapter is online .."
                        echo "I will proceed with the test execution"
                        cleanup_scsi_reqd=0
                else
                        assert_exec 0 $chccwdev_tool_path -e $scsi_adapter
                        sleep 3
                        if [ -d /sys/bus/ccw/drivers/zfcp/$scsi_adapter/$scsi_wwpn ]
                        then
                                echo $scsi_lun > /sys/bus/ccw/drivers/zfcp/$scsi_adapter/$scsi_wwpn/unit_add
                                sleep 2
                        else
                                echo $scsi_wwpn > /sys/bus/ccw/drivers/zfcp/$scsi_adapter/port_add
                                sleep 1
                                echo $scsi_lun > /sys/bus/ccw/drivers/zfcp/$scsi_adapter/$scsi_wwpn/unit_add
                                sleep 2
                        fi
                        cleanup_scsi_reqd=1
                fi
        else
                # Check if this is a z/VM guest running Linux
                isVM
                if [ $? == 0 ]
                then
                        if [ load_vmcp != 0 ]
                        then
                                modprobe vmcp
                        fi
                        temp=`echo $scsi_adapter | awk -F. '{print $3}'`

                       echo "Adeptor "$temp
                        echo "Setting device $scsi_adapter online"
                        assert_exec 0 vmcp attach $temp to \\*
                        sleep 3
                                cleanup_scsi_reqd=1
                fi
                # Online the scsi adapter
                assert_exec 0 $chccwdev_tool_path -e $scsi_adapter
                sleep 3
                if [ -d /sys/bus/ccw/drivers/zfcp/$scsi_adapter/$scsi_wwpn ]
                then
                        echo $scsi_lun > /sys/bus/ccw/drivers/zfcp/$scsi_adapter/$scsi_wwpn/unit_add
                        sleep 2
                else
                        echo $scsi_wwpn > /sys/bus/ccw/drivers/zfcp/$scsi_adapter/port_add
                        echo $scsi_lun > /sys/bus/ccw/drivers/zfcp/$scsi_adapter/$scsi_wwpn/unit_add
                        sleep 2
                fi
        fi

        scsi_device=`lsscsi | tail -1 | awk  '{ print $5 }'`
        echo "scsi device = $scsi_device"


}

if [ $# == 3 ]

then
        scsi_adapter=$1
        scsi_wwpn=$2
        scsi_lun=$3
        setup_scsi
else

  echo "Insufficent parameter please provide fcp adaptor wwpn and lun"
  exit
fi
