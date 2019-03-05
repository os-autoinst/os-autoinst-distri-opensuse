# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

##############################################
## TEST : LVM Linear, Striped & Mirrored test
###############################################

DEVELOPMENTMODE="yes"

############################
## INCLUDING THE LIB SCRIPTS
############################
for f in lib/*.sh; do source $f; done
source ./00_LVM_TOOLS.sh || exit 1

#############################
## INTIALIZE/DEFINE VARIABLES
#############################
LVS=""
count=0
DEVICE=""
PARTITIONS=""

################
# Main function
################
init_tests

start_section 0 "LOGICAL VOLUME MANAGER TESTS "

start_section 1 "LVM TYPES: Linear, Striped, Mirrored LVM"


echo "Re-group all devices for stress test....";echo
assert_exec 0 "pvscan";echo
PVS=`pvscan | grep /dev/ | awk '{print $2}'`
RET=$?
assert_warn $RET 0 "`date` physical volumes not found !"
[ $RET != 0 ] && end_section 1 && _clean_up && exit 1

for DEVICE in $PVS;do
	count=`expr $count + 1`
	echo "reuse $DEVICE for lvm.."
	PARTITIONS="$DEVICE $PARTITIONS"
	sleep 2
	if [ $count == 3 ]
	then
		_create_VGs vg_linear $PARTITIONS
		sleep 2
		_create_linear_LVs vg_linear
		sleep 2
		_create_fs_on_LVs /dev/vg_linear/test_linear_lv0
		sleep 2
		_mount_LVs /dev/vg_linear/test_linear_lv0 linear
		sleep 2
		PARTITIONS=""
	fi

	if [ $count == 6 ]
	then

		_create_VGs vg_striped $PARTITIONS
		sleep 2
		_create_striped_LVs vg_striped
		sleep 2
		_create_fs_on_LVs /dev/vg_striped/lvol0
		sleep 2
		_mount_LVs /dev/vg_striped/lvol0 striped

		PARTITIONS=""

	fi

	if [ $count == 9 ]
	then

		_create_VGs vg_mirrored $PARTITIONS
		sleep 2
		_create_mirror_LVs vg_mirrored
		sleep 2
		_create_fs_on_LVs /dev/vg_mirrored/lvol0
		sleep 2
		_mount_LVs /dev/vg_mirrored/lvol0 mirrored

		PARTITIONS=""
	fi

done

echo "Start IO on all mounted logical volumes";echo
_init_IO

echo "unmount the created logical volumes:";echo
mnt_pnt=""
# for mnt_pnt in linear striped mirrored ;do
for mnt_pnt in linear ;do

	_un_mount_LVs $mnt_pnt
	sleep 2
done
echo "Clean the logical volumes";echo
lv=""
# for lv in /dev/vg_linear/test_linear_lv0 /dev/vg_mirrored/lvol0 /dev/vg_striped/lvol0 ;do
for lv in /dev/vg_linear/test_linear_lv0;do

	_lv_clean $lv
	sleep 2
done

echo "Clean volume groups";echo
vg=""
# for vg in vg_linear vg_striped vg_mirrored ;do
for vg in vg_linear ;do

	_vg_clean $vg
	sleep 2
done

echo "keep physical volumes for future tests";echo

end_section 1

end_section 0

show_test_results
