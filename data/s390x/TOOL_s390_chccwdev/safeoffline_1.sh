# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

for f in lib/*.sh; do source $f; done
source ./lib_soffline.sh || exit 1



DEV_HPAV=$3
DEV_HPALIAS=$4
MDISK=$5
FBA_DEV=$6
CLIENT_MC=$7
if [ "$1" != "tbd" ]; then
    DEV_PAV=$1;
    DEV_PALIAS=$2
else
    echo "Parameter for DEV_PAV is: $DEV_PAV";
    echo "Skipping tests for DEV_PAV and DEV_PALIAS";
fi


if (isVM) ; then
    modprobe vmcp
    #vmcp att $DEVICE '*'
    if [ -n "${DEV_PAV}" ]; then
        vmcp att "$DEV_PAV" '*'
        vmcp att "$DEV_PALIAS" '*'
    fi
    vmcp att "$DEV_HPAV" '*'
    vmcp att "$DEV_HPALIAS" '*'
    #vmcp att $SCSI '*'
    sleep 3
fi

init_tests

start_section 0 "Safe offline advance tests"

start_section 1 "safe offline PAV aliases while I/O"

echo "This test will safe offline PAV aliases while blast IO running"

#Activate the PAV base
assert_exec 0 "chccwdev -e $DEV_PAV"

#Activate PAV aliases
######## Update ##########
chccwdev -e "$DEV_PALIAS"
#_online_aliases $DEV_PALIAS

echo "List PAV base and PAV aliases"
assert_exec 0 "lsdasd"

#Find the dev node of the PAV device
DEV_NODE="$(lsdasd | grep "$DEV_PAV" | awk '{print $3}')"

dasdfmt -b 4096 -d cdl "/dev/$DEV_NODE" -y
sleep 5
#Create a partition on PAV DEVICE
echo "Create a single partion on PAV base.."
assert_exec 0 "fdasd -a /dev/$DEV_NODE"

sleep 2

#Create a filesystem on PAV partition
assert_exec 0 "mkfs -t ext3 /dev/${DEV_NODE}1"

sleep 2

if [ -e /mnt/1 ];then
	echo "File already exists"
else
	assert_exec 0 "mkdir /mnt/1"
fi

#Mount the filesystem
echo "Mount the file system created on PAV base"
assert_exec 0  "mount /dev/${DEV_NODE}1 /mnt/1"

#List the mounted filesystem
assert_exec 0 "mount"

#Start the blast IO on the mounted filesytem
start_blast

#Safe offline all the PAV aliases
########## Update ########
chccwdev -s -d "$DEV_PALIAS"
#_s_offline_aliases $DEV_PALIAS

#Online all the PAV aliases
chccwdev -e "$DEV_PALIAS"
#_online_aliases $DEV_PALIAS

end_section 1

start_section 1 "safe offline/online PAV aliases while I/O"

# Safe offline / online PAV aliases in a loop while the blasst IO is running on the PAV BASE.
# The I/O tobe expected to contine without I/O stall or hang

echo "Safe offline / online PAV aliases  in a loop while the blasst IO running on PAV BASE."
<<comment1
for (( i=0; i<2; i++ ))
do
	_s_offline_aliases $DEV_PALIAS

	sleep 2

	_online_aliases $DEV_PALIAS

	sleep 2
done
comment1
#Stop the blast IO..
kill_blast

sleep 2

#Unmount the filesystem
echo "Unmount the filesystem"
assert_exec 0 "umount /dev/${DEV_NODE}1"

#Safe offline the aliases
echo "Safe offline all the PAV aliases"
##### Update ####
chccwdev -s -d "$DEV_PALIAS"
#_s_offline_aliases $DEV_PALIAS

#Safe offline the PAV BASE
echo "Safe offline the PAV base"
assert_exec 0 "chccwdev -s $DEV_PAV"

end_section 1

start_section 1 "Safe offline on HyperPAV aliases while IO"

echo "Safe offline the aliases of HPAV while blast IO is running"

#Activate the HPAV base
assert_exec 0 "chccwdev -e $DEV_HPAV"

#Activate HPAV aliases
_online_aliases "$DEV_HPALIAS"

#Find the dev node of the HPAV device
DEV_NODE="$(lsdasd | grep "$DEV_HPAV" | awk '{print $3}')"

dasdfmt -b 4096 -d cdl "/dev/$DEV_NODE" -y
sleep 5
#Create a partition on HPAV DEVICE
echo "Create single partition on Hyper PAV base"
assert_exec 0 "fdasd -a /dev/$DEV_NODE"

sleep 2

#Create a filesystem on HPAV partition
assert_exec 0 "mkfs -t ext3 /dev/${DEV_NODE}1"

sleep 2

if [ -e /mnt/1 ];then
	echo "File already exists"
else
	assert_exec 0 "mkdir /mnt/1"
fi

#Mount the filesystem
echo "Mount the filesystem"
assert_exec 0  "mount /dev/${DEV_NODE}1 /mnt/1"

#List the mounted filesystem
echo "Listing the mounted filesytems on the system"
assert_exec 0 "mount"

#Start the blast IO on the mounted filesytem
start_blast

#Safe offline all the HPAV aliases
_s_offline_aliases "$DEV_HPALIAS"

#Online all the HPAV aliases
_online_aliases "$DEV_HPALIAS"

end_section 1

#Hyper PAV aliases offline / online in a loop while blast IO running on HyperPAV BASE

start_section 1 "Safe offline HyperPAV aliases while I/O HPAV BASE"

echo "Safe offline / online HyperPAV aliases in a loop while the blasst IO running on PAV BASE."

<<comment2
for (( i=0; i<2; i++ ))
do
	_s_offline_aliases $DEV_HPALIAS

	sleep 2

	_online_aliases $DEV_HPALIAS

	sleep 2
done
comment2

sleep 2

#Unmount the filesystem
assert_exec 0 "umount /dev/${DEV_NODE}1"

#Safe offline the aliases
_s_offline_aliases "$DEV_HPALIAS"

#Safe offline the HPAV BASE
assert_exec 0 "chccwdev -s $DEV_HPAV"

end_section 1
#########################################################################################
start_section 1 "Safe offline MINI DISK"

if isVM; then
	assert_warn 0 0 "The test environment is zVM. Continue with tests"

	echo " Link the mini disk $MDISK to the zVM Guest"

	#Linking minidisk to the zVM Guest
	_link_minidisk "$MDISK"

	sleep 2

	#Activate minidisk on zVM Guest
	echo "Activate the minidisk $MDISK on the zVM Guest"
	assert_exec 0 "chccwdev -e $MDISK"

	sleep 2

	#List the dasd's  on the system
	echo "Listing the activated dasd's on the system"
	assert_exec 0 "lsdasd"

	sleep 2

	#Safe offline the minidisk"
	echo "Safe offline mini disk $MDISK"
	assert_exec 0 "chccwdev -s $MDISK"

	#Verify if the mini disk offlined safely
	echo "List the available dasd's on the system"
	assert_exec 0 "lsdasd"

	sleep 2

	#Unlink minidisk from the zVM Guest
	echo "Unlink the minidisk $MDISK from zVM Guest"
	_unlink_minidisk "$MDISK"
else
	assert_warn 0 0 "The test environment is Logical partition (LPAR). Cant continue this test"
fi

end_section 1

./soffline_2.sh