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

function remove_scsi()
{
         echo "removing Scsi Device From the test system"

         echo $scsi_lun > /sys/bus/ccw/drivers/zfcp/$scsi_adapter/$scsi_wwpn/unit_remove
         sleep 2
         assert_exec 0 $chccwdev_tool_path -d $scsi_adapter
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
                        assert_exec 0 vmcp det $temp
                        sleep 3

                fi


}

if [ $# == 3 ]

then
        scsi_adapter=$1
        scsi_wwpn=$2
        scsi_lun=$3
        remove_scsi
else

  echo "Insufficent parameter please provide fcp adaptor wwpn and lun"
  exit
fi
