# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

#############################################################
## TEST : LOGICAL VOLUME MANAGER
## HOWTO: SCRIPT ACCEPTS COMMNAD LINE ARGS
##	  $1 HPAV BASE DEVICES IOCTL
##	  $2 HPAV ALIAS DEVICES IOCTL
#############################################################

DEVELOPMENTMODE="yes"

############################
## INCLUDING THE LIB SCRIPTS
############################
for f in lib/*.sh; do source $f; done

source ./export_variables.sh $1 $2 || exit 1
source ./00_LVM_TOOLS.sh || exit 1

#############################
## INTIALIZE/DEFINE VARIABLES
#############################

s390_config_check CONFIG_BASE_PAV
s390_config_check CONFIG_ALIAS_PAV

BASE_PAV=$CONFIG_BASE_PAV
ALIAS_PAV=$CONFIG_ALIAS_PAV
DEVNO=""
LVS=""
PARTITIONS=""


################
# Main function
################
init_tests

dmesg -c >/dev/null

start_section 0 "LOGICAL VOLUME MANAGER TESTS "

start_section 1 "LVM BASIC Test and RC's"

echo "Prepare the devices to be used...";echo
_init_dasd_setup $BASE_PAV $ALIAS_PAV

echo "Initial cleanup to remove old setups..."
_init_lvm_check

echo "Create a physical volumes";echo
_create_PVs

echo "Create a volume group:";echo
_create_VGs test_vg0

echo "Create a logical volume";echo
_create_linear_LVs test_vg0

echo "create filesystem on the logical volume";echo
_create_fs_on_LVs /dev/test_vg0/test_linear_lv0

echo "Mount the created logical volume /dev/test_vg0/test_linear_lv0 to /media/test_linear_lv0";echo
_mount_LVs /dev/test_vg0/test_linear_lv0 linear

echo "Start IO on mounted logical volume /media/test_linear_lv0";echo
_init_IO
# sleep 10

echo "unmount the created logical volume: test_linear_lv0 on /mnt/linear";echo
_un_mount_LVs linear

echo "Clean the logical volume: test_linear_lv0";echo
_lv_clean /dev/test_vg0/test_linear_lv0

echo "Clean volume group: test_vg0";echo
_vg_clean test_vg0

echo "keep the physical volumes for future tests......";echo

echo "no clean up required as devices are needed for other test...";echo

end_section 1

end_section 0

show_test_results
