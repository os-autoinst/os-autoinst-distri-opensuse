# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

######################################################
## TEST : LVM Snapshot & backup test
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
ALIAS_IDS=`lsdasd | grep "alias" | awk '{print $1}'`

################
# Main function
################
init_tests

start_section 0 "LOGICAL VOLUME MANAGER TESTS "

start_section 1 "LVM TYPES: test snapshot functionality"


DEVICE=""
BUS_ID=""
PARTITIONS=""
echo "Re-group all devices for snapshot test....";echo
assert_exec 0 "pvscan";echo
PVS=`pvscan | grep /dev/ | awk '{print $2}'`
RET=$?
assert_warn $RET 0 "`date` physical volumes not found !"
[ $RET != 0 ] && end_section 1 && _clean_up && exit 1

for DEVICE in $PVS;do
	echo "reuse $DEVICE for lvm.."
	PARTITIONS="$DEVICE $PARTITIONS"
	TMP=`echo $DEVICE | cut -c1-10 `
	get_bus_id $TMP
	BASE_IDS="$BUS_ID $BASE_IDS"
	sleep 2
done
rm -rf /mnt/linear
rm -rf /mnt/backup

_create_VGs vg_linear $PARTITIONS
sleep 2
size=`vgdisplay | grep "VG Size" | awk -F " " '{ printf $3 }' | cut -f 1 -d "."`
let "new_size = $size / 2"
sleep 2

assert_exec 0 "lvcreate --yes -L "$new_size"G -n test_linear_lv0 vg_linear"
sleep 2

_create_fs_on_LVs /dev/vg_linear/test_linear_lv0
sleep 2
_mount_LVs /dev/vg_linear/test_linear_lv0 linear
sleep 2

echo "Start IO on mounted logical volume";echo
_init_IO

now=$(date +%Y%m%d)

_create_snapshot_LVs $new_size

mkdir /mnt/backup

_mount_LVs /dev/vg_linear/lvbackup backup

assert_exec 0 "tar -pczf /root/log/lvsnap$(date +%Y%m%d).tar.gz /mnt/backup"

echo "Start IO on mounted logical volume";echo
_init_IO

#check the backup and orginal data size
lvsize=`lvdisplay /dev/vg_linear/test_linear_lv0 | grep "LV Size" | awk -F " " '{print $3}'`
snapshotsize=`lvdisplay /dev/vg_linear/lvbackup | grep "LV Size" | awk -F " " '{print $3}'`
if [ $lvsize == $snapshotsize ];
then
	echo "data size is equal"
else
	echo "some data is missing"
fi

assert_exec 0 "umount /mnt/backup";echo

assert_exec 0 "umount /mnt/linear";echo
sync
sleep 5
_lv_clean /dev/vg_linear/lvbackup
sleep 3
_lv_clean  /dev/vg_linear/test_linear_lv0


echo "##################### continuous snapshot and backup ########";echo

assert_exec 0 "lvcreate --yes -L "$new_size"G -n test_linear_lv0 vg_linear"
sleep 2
_create_fs_on_LVs /dev/vg_linear/test_linear_lv0

_mount_LVs /dev/vg_linear/test_linear_lv0 linear
sleep 2

echo "Start IO on mounted logical volume";echo
_init_IO

for i in $(seq 2);do

	_create_snapshot_LVs $new_size
	mkdir /mnt/backup
	_mount_LVs /dev/vg_linear/lvbackup backup
	assert_exec 0 "tar -pczf /root/log/lvsnap$(date +%Y%m%d).tar.gz /mnt/backup"
	sleep 5
	assert_exec 0 "umount /mnt/backup";echo
	_lv_clean /dev/vg_linear/lvbackup
	assert_exec 0 "rm -rf /mnt/backup"
	assert_exec 0 "rm -rf /root/log/*.gz"
	sleep 5

done

assert_exec 0 "umount /mnt/linear";echo
sleep 2

_lv_clean  /dev/vg_linear/test_linear_lv0

echo "Clean volume groups";echo
_vg_clean vg_linear

echo "Clean physical volumes from LVM";echo
_pv_clean

echo "Clean up process started...";echo

echo "offline HPAV alias first.."
_clean_up "$ALIAS_IDS"
sleep 2

echo "offline HPAV base now.."
_clean_up "$BASE_IDS"

end_section 1

end_section 0

show_test_results
