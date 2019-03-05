# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

######################################################
## TEST : LVM RESIZE TEST
######################################################

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
BASE_IDS=""

################
# Main function
################
init_tests

start_section 0 "LOGICAL VOLUME MANAGER TESTS "

start_section 1 "LVM RESIZE TEST"

echo "~~~~~~ test increasing (online) & decreasing (offline) of a linear logical volume ~~~~~~"
count=0
DEVICE=""
PARTITIONS=""
echo "Re-group all devices for next test....";echo
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
	if [ $count == 9 ]
	then
		echo "keep remaining pvs to add later...."
		echo "$PARTITIONS"
	fi
done
df -h;echo
echo "Start IO on mounted logical volume";echo
_init_IO


echo "###################### online expand logiccal volume multiple times #######################"
echo "Start adding devices vgextend vg_linear /dev/pvs"
disk=""
for disk in $PARTITIONS ;do
	assert_exec 0 "vgextend vg_linear $disk";echo
	vgdisplay | grep Size;echo
	pvscan

	echo "Extend the logical volume lvextend -L+500M /dev/vg_linear/test_linear_lv0"

	assert_exec 0 "lvextend -L+500M /dev/vg_linear/test_linear_lv0";echo
	echo;df -h;echo
	lvscan

	echo "resize the fs resize2fs"
	resize2fs /dev/vg_linear/test_linear_lv0
	echo;df -h;echo
	sync
	sleep 5
done
echo "unmount the created logical volumes:";echo
_un_mount_LVs linear
sleep 2
df -h;echo

echo "#################### offline shrink logical volume ################## "
echo "Clean filesystem before shrink"
e2fsck -f -y /dev/vg_linear/test_linear_lv0
sleep 2
_mount_LVs /dev/vg_linear/test_linear_lv0 linear
echo "remove the data in the LV and shrink"
rm -rf /mnt/linear/*
df -h;echo
_un_mount_LVs linear

echo "shrink and reduce volume group and remove pvs"
size=`lvdisplay | grep "LV Size" | awk -F " " '{ printf $3 }' | cut -f 1 -d "."`
let "new_size = $size / 2"
e2fsck -f -y /dev/vg_linear/test_linear_lv0
sleep 2
resize2fs /dev/vg_linear/test_linear_lv0 "$new_size"G
sleep 2
echo "shrink $new_size size lvresize /dev/vg_linear/test_linear_lv0 -L-"$new_size"G"
assert_exec 0 "lvresize /dev/vg_linear/test_linear_lv0 -L-"$new_size"G -f"
sleep 2

echo "Reduce the volume group too..: vgreduce -a"
assert_exec 5 "vgreduce -a vg_linear"
sleep 2
echo "check for removed physical volumes from the vg"
pvscan | grep -v VG;echo

echo "check the new size:df -h :"
lvdisplay | grep "LV Size" | awk -F " " '{ printf $3 }' ;echo

echo "Mount the logical volume and start I/O again"
_mount_LVs /dev/vg_linear/test_linear_lv0 linear

echo "Start IO on mounted logical volume";echo
_init_IO
echo "Unmount the created logical volumes:";echo
_un_mount_LVs linear
sleep 2

echo "Clean the logical volumes";echo
_lv_clean /dev/vg_linear/test_linear_lv0

echo "Clean volume groups";echo
_vg_clean vg_linear

rm -rf /mnt/linear
echo "Keep the physical volumes for future tests......";echo

end_section 1

end_section 0

show_test_results
