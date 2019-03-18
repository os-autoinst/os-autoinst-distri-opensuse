# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

for f in lib/*.sh; do source $f; done


itrn=1

####################################FBA################################

function _create_fba ()
{
	if ( isVM )
	then
		FBA_DEV="$1"
		assert_exec 0  "vmcp def vfb-512 $FBA_DEV 40000"

		sleep 3

		if [ -e "/sys/bus/ccw/devices/0.0.$FBA_DEV" ]
		then
			echo "fba device $FBA_DEV created successfully"
		else
			echo "fba device $FBA_DEV FAILED to create.."
		#	exit 1
		fi
	else
		assert_warn 0 0 "The test environment is LPAR. This test can only be performed on zVM environment"
	fi

}

function _remove_fba ()
{
	FBA_DEV="$1"

	if [ -e "/sys/bus/ccw/devices/0.0.$FBA_DEV" ]
	then
		assert_fail 0 0 "FBA device found"

		echo "Remove fba from zVM Guest"
		assert_exec 0 "vmcp det $FBA_DEV"

		if [ -e "/sys/bus/ccw/devices/0.0.$FBA_DEV" ]
		then
			assert_warn 1 0 "FBA Device failed to detach from zVM"
		else
			assert_fail 0 0 "FBA device successfully from zVM  Guest"
		fi
	else
		assert_warn 0 0 "FBA device not found. Nothig to dettach"
	fi
}

function _link_minidisk ()
{
	HOST=`hostname`
	MDISK=$1
	echo "Link the mdisk to zVM $HOST"
	assert_exec 0 "vmcp link linmdisk $MDISK $MDISK m"

	assert_exec 0 "vmcp q mdisk $MDISK"

	if [ -e /sys/bus/ccw/devices/0.0.$MDISK ]
	then
		echo "mdisk $MDISK successfully linked to host $HOST"
	else
		echo "mdisk $MDISK failed to  link to host $HOST"
	fi
}

function _unlink_minidisk ()
{
	HOST=`hostname`
        MDISK=$1
        echo "Unlink the mdisk $MDISK from zVM $HOST"
        assert_exec 0 "vmcp det $MDISK"
	if [ -e /sys/bus/ccw/devices/0.0.$MDISK ]
        then
                echo "Failed to unlink mdisk $MDISK from  host $HOST"
        else
                echo "mdisk $MDISK successfully unlinked from  host $HOST"
        fi
}

########### offline the aliases PAV / HYPER PAV ##############

function _list_aliases ()
{
	array=""
	SAlias=`echo $1 | awk -F "-" '{ printf $1 }' | tr '[:lower:]' '[:upper:]'`
	EAlias=`echo $1 | awk -F "-" '{ printf $2 }' | tr '[:lower:]' '[:upper:]'`
	DSalias=`echo "ibase=16; $SAlias" | bc`
	DEalias=`echo "ibase=16; $EAlias" | bc`

	for (( i=$DSalias ; i<=$DEalias; i++ ))
	do
		echo "obase=16; $i" | bc
		tmp=$(echo "obase=16; $i" | bc)
		array="$array $tmp"
		#printf $array
	done
}

function _s_offline_aliases ()
{
	ALIASES=$(_list_aliases $1)

	for alias in `echo $ALIASES`
	do
		echo "Safe offline aliases $alias .."
		assert_exec 0 "chccwdev -s $alias"

		sleep 5

		lsdasd | grep $alias

		if [ $? != 0 ]
		then
			echo "The alias $alias offline successfully.."
		else
			echo "Safe offling alias $alias failed"
		fi

		echo "Safe offline all the aliases of PAV / HYPER PAV device.."

		echo "List the eckd devices .."
		assert_exec 0  "lsdasd"
	done
}


function _online_aliases ()
{
	ALIASES=$(_list_aliases $1)

	for alias in `echo $ALIASES`
	do
                echo "Online alias $alias .."
                assert_exec 0 "chccwdev -e $alias"

		sleep 2

		lsdasd | grep $alias

		if [ $? == 0 ]
                then
                        echo "The alias $alias online successfully.."
                else
                        echo "Online alias $alias failed"
                fi

	        echo "Online all the aliases of PAV / HYPER PAV device.."

		echo "List the eckd devices .."
	        assert_exec 0  "lsdasd"
	done
}


function _reserve_lock ()
{
	SYSTEM2=$1
	DEVICE=$2

	echo "Online $DEVICE on system2 $SYSTEM2.."
	assert_exec 0 "ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root chccwdev -f $DEVICE"
	assert_fail $? 0 "Device online successfully. Test passed"

	echo "Query the devnode of $DEVICE on system2 $SYSTEM2.."

	DEVNODE_SYSTEM2=$(ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root lsdasd | grep $DEVICE | awk {'print $3'})

	echo "Reserve $DEVICE on system2 $SYSTEM2..."

	assert_exec 0 "ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root tunedasd -S /dev/$DEVNODE_SYSTEM2"
	assert_fail $?  0 "Device $DEVICE successfully reserved on system2 $SYSTEM2"

	echo "Query stataus of the device $DEVICE on system2 $SYSTEM2.."

	assert_exec 0 "ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root tunedasd -Q /dev/$DEVNODE_SYSTEM2"

}

function _release_lock ()
{
	SYSTEM2=$1
	DEVICE=$2

	echo "Online $DEVICE on system2 $SYSTEM2.."
	assert_exec 0 "ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root chccwdev -f $DEVICE"
	assert_fail $? 0 "Device online successfully. Test passed"

#	echo "Query the devnode of $DEVICE on system2 $SYSTEM2.."

	DEVNODE_SYSTEM2=$(ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root lsdasd | grep $DEVICE | awk {'print $3'})

	echo "Release $DEVICE on system2 $SYSTEM2..."

	assert_exec 0 "ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root tunedasd -L /dev/$DEVNODE_SYSTEM2"
	assert_fail $?  0 "Device $DEVICE successfully released from system2 $SYSTEM2"

	echo "Query stataus of the device $DEVICE on system2 $SYSTEM2.."

	assert_exec 0 "ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root tunedasd -Q /dev/$DEVNODE_SYSTEM2"

	echo "Offline $DEVICE on system2 $SYSTEM2.."
        assert_exec 0 "ssh  -o StrictHostKeyChecking=no -oProtocol=2  -oBatchMode=yes -i /root/.ssh/id_dsa.autotest $SYSTEM2 -l root chccwdev -d $DEVICE"
        assert_fail $? 0 "Device offline successfully. Test passed"
}
