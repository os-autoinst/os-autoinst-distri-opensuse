# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

for f in lib/*.sh; do source $f; done

lsreipl_tool_path=$(s390_get_tool_path lsreipl)
chreipl_tool_path=$(s390_get_tool_path chreipl)
chccwdev_tool_path=$(s390_get_tool_path chccwdev)

if [ $# -ne 4 ]
then
	echo "No arguments specified for the script"
	exit
fi

dasd_adapter=$1
scsi_adapter=$2
scsi_wwpn=$3
scsi_lun=$4
dasd=
dasd_device=
cleanup_dasd_reqd=0
cleanup_scsi_reqd=0


function setup_dasd()
{
	start_section 2 "Setup dasd device for the test"

	if [ -d /sys/bus/ccw/devices/$dasd_adapter ]
        then
		is_online=`cat /sys/bus/ccw/devices/$dasd_adapter/online`
		if [ $is_online -eq 1 ]
		then
			echo "Device $dasd_adapter is online .."
			echo "I will proceed with the test execution"
			cleanup_dasd_reqd=0
		else
			assert_exec 0 $chccwdev_tool_path -e $dasd_adapter
			sleep 2
                        cleanup_dasd_reqd=1
		fi
	else
		attached=1
		# Check if this is a z/VM guest running Linux
                isVM
                if [ $? == 0 ]
                then
                        if [ load_vmcp != 0 ]
                        then
                                modprobe vmcp
                        fi
                        temp=`echo $dasd_adapter | awk -F. '{print $3}'`
                        echo "Attach device $dasd_adapter"
                        assert_exec 0 vmcp attach $temp to \\*
			if [ $? != 0]
			then
				attached=0
			fi
                        sleep 2
                        cleanup_dasd_reqd=1
		fi
		if [ $attached == 1 ]
		then
			echo "Setting device $dasd_adapter online"
			assert_exec 0 $chccwdev_tool_path -e $dasd_adapter
			sleep 2
			cleanup_dasd_reqd=1
                fi
	fi

	dasd=`lsdasd | grep $dasd_adapter | awk '{print $3}'`
	dasd_device="/dev/$dasd"
	#echo $dasd_device
	assert_warn 1 1 "Device $dasd_device is online"

	end_section 2
}

function setup_scsi()
{
	start_section 2 "Setup scsi device for the test"

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

	echo "scsi device = $scsi_device"

	end_section 2
}

function setup()
{
	start_section 1 "Setup environment for the test"
	setup_dasd
	setup_scsi
	end_section 1
}

function cleanup()
{
	start_section 1 "Cleanup environment after test execution"

	if [ $cleanup_dasd_reqd -eq 1 ]
	then
		echo "Setting device $dasd_adapter offline"
		assert_exec 0 $chccwdev_tool_path -d $dasd_adapter
		sleep 3
		isVM
                if [ $? == 0 ]
                then
			temp=`echo $dasd_adapter | awk -F. '{print $3}'`
			vmcp detach $temp
			sleep 2
			rmmod vmcp
		fi
	fi
	if [ $cleanup_scsi_reqd -eq 1 ]
	then
		echo "Setting device $dasd_adapter offline"
		assert_exec 0 $chccwdev_tool_path -d $scsi_adapter
		sleep 2
		isVM
                if [ $? == 0 ]
                then
			temp=`echo $scsi_adapter | awk -F. '{print $3}'`
			vmcp detach $temp
			sleep 2
			rmmod vmcp
		fi
	fi

	end_section 1
}
