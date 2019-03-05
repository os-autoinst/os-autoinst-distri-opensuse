# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
#DEVNOS="XXXX XXXX XXXX XXXX XXXX XXXX" # Consider for RAID10 Minimum is 6 DASDs!!!
DEVNOS=$1

ITERATIONS=2 # Number of times this script is being executed
LOOPS="2" #Number of loops IO test will be performed. If LOOPS=0 no IO test will be executed
LUNS=
WWPNS=
MNT=1

for f in lib/*.sh; do source $f; done

start_section 0 "btrfs test on ECKD devices - Each DASD on single mount point"

assert_warn 0 0 "Executing $LOOPS IO test Loops for $ITERATIONS times"

for (( z = 1; z <= $ITERATIONS; z++ )); do
	DASDS=""
	for DEVNO in $DEVNOS; do
		DASD=`echo $DEVNO | tr "A-Z" "a-z"`
		DASDS="/dev/disk/by-path/ccw-0.0.$DASD $DASDS"
	done
	# Setting DASD devnos online
	for DEVNO in $DEVNOS; do

		echo DEVNO $DEVNO
		is_online=$(cat /sys/bus/ccw/devices/0.0.$DEVNO/online)
		if [ $is_online -eq 0 ]; then
			echo 1 > /sys/bus/ccw/devices/0.0.$DEVNO/online
			cat /sys/bus/ccw/devices/0.0.$DEVNO/online
			[ `cat /sys/bus/ccw/devices/0.0.$DEVNO/online` = 1 ]
		fi
		RET=$?
		assert_warn $RET 0 "Setting DASD with device number $DEVNO online. Iteration: $z of $ITERATIONS"
		[ $RET != 0 ] && end_section 0 && clean_up && exit 1



		# echo DEVNO $DEVNO
		# echo 1 > /sys/bus/ccw/devices/0.0.$DEVNO/online
		# cat /sys/bus/ccw/devices/0.0.$DEVNO/online
		# [ `cat /sys/bus/ccw/devices/0.0.$DEVNO/online` = 1 ]
		# RET=$?
		# assert_warn $RET 0 "Setting DASD with device number $DEVNO online. Iteration: $z of $ITERATIONS"
		# [ $RET != 0 ] && end_section 0 && clean_up && exit 1
	done

	sleep 3

	# Cleaning routing - cleaning up everything
	clean_up ()
	{
		for DASD in $DASDS; do
			# unmounting DASDs again
			umount $DASD-part1
		done
		return 0
	}

	# Just un-mounting DASDs
	u_mount ()
	{
		for DASD in $DASDS; do
			umount $DASD-part1
		done
		return 0
	}

	wait_for_mkfs.btrfs ()
	{
		while [ `ps aux | grep -c1 mkfs.btrfs` -gt 1 ]; do
			sleep  1
		done
		sleep 2
	}


	_init_IO(){
		touch /mnt1/hugefile
		dd if=/dev/zero of=/mnt1/hugefile count=100 bs=1048576
		RET=$?
		assert_warn $RET 0 "`date` IO test executed"
		[ $RET != 0 ] && end_section 0 && exit 1
	}

	# Perform un-mount and cleanup in case something is still mounted
	# u_mount
	# clean_up
	sleep 1
	# Mounting each of the devices on a separate mount point create fs and run stress against them
	MOUNT=0
	clean_up
	for DASD in $DASDS; do
		#Create 1 Partition per DASD
		fdasd -s -a $DASD
		RET=$?
		assert_warn $RET 0 "Creation of partition on DASD $DASD.  Iteration: $z of $ITERATIONS"
		[ $RET != 0 ] && end_section 0 && clean_up && exit 1
		sleep 5 # sleep to wait for udev  ...
		# Create btrfs filesystem on DASD
		mkfs.btrfs -f $DASD-part1
		RET=$?
		assert_warn $RET 0 "Creation of btrfs filesystem on DASD $DASD-part1. Iteration: $z of $ITERATIONS"
		RET=$?
		[ $RET != 0 ] && end_section 0 && clean_up && exit 1
		let MOUNT=$MOUNT+1
		mkdir -p /mnt$MOUNT 2> /dev/null
		wait_for_mkfs.btrfs
		mount $DASD-part1 /mnt$MOUNT
		RET=$?
		assert_warn $RET 0 "Mounting DASD $DASD-part1 to mountpoint /mnt$MOUNT. Iteration: $z of $ITERATIONS"
		[ $RET != 0 ] && end_section 0 && exit 1

	done

	# Performing IO tests

	MOUNT=0
	if [ $LOOPS -gt 0 ]; then
		_init_IO
		RET=$?
		assert_warn $RET 1 "IO test is being executed in $LOOPS number of loops. Iteration: $z of $ITERATIONS"
		[ $RET != 1 ] && end_section 0 && clean_up && exit 1
	fi

	u_mount
	clean_up
	end_section 0
	#################################
	#################################

	start_section 0 "btrfs test on ECKD devices - All DASDs together in a raid10 cluster"

	for DASD in $DASDS; do
		#Create 1 Partition per DASD
		fdasd -s -a $DASD
		RET=$?
		assert_warn $RET 0 "Creation of partition on DASD $DASD during RAID10 test. Iteration: $z of $ITERATIONS"
		[ $RET != 0 ] && end_section 0 && clean_up && exit 1
	done
	sleep 5

	for PART in $DASDS; do
		PARTITIONS="$PART-part1 $PARTITIONS"
	done

	echo PARTS: $PARTITIONS

	mkfs.btrfs -m raid10 -d raid10 -f $PARTITIONS
	RET=$?
	assert_warn $RET 0 "Creating a RAID10 cluster of disks: mkfs.btrfs -m raid10 -d raid10 $PARTITIONS. Iteration: $z of $ITERATIONS"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1

	wait_for_mkfs.btrfs
	mkdir -p /mnt1

	MOUNTDEV=`echo $DASDS | awk '{print $1}'` # first device in the list mounts the cluster

	mount "$MOUNTDEV-part1" /mnt1
	RET=$?
	assert_warn $RET 0 "Mounting btrfs RAID10 device $MOUNTDEV-part1 on /mnt1. Iteration: $z of $ITERATIONS"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1

	# Check whether all devnos have been used in the array
	[ `btrfs filesystem show | grep -c devid` -gt `echo $DEVNOS | wc -w` ]
	RET=$?
	assert_warn $RET 0 "Prove all DASDs have been used for the RAID10 cluster 'btrfs filesystem show'. Iteration: $z of $ITERATIONS"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1


	[ $RET != 0 ] && end_section 0 && clean_up && exit 1
	if [ $LOOPS -gt 0 ]; then
		_init_IO
		RET=$?
		assert_warn $RET 1 "IO test is being executed in $LOOPS number of loops on RAID10 device. Iteration: $z of $ITERATIONS"
		[ $RET != 1 ] && end_section 0 && clean_up && exit 1
	fi

	# Testing snapshot on just above created RAID10

	# CHECKSUM_SOURCE=`find /mnt1  -type f -print0 | xargs -0 md5sum | md5sum -b`
	# checksumming did not work for me  ....
	sleep 10
	SIZE_SOURCE=`du -ks /mnt1/ | awk '{print $1}'`

	btrfs subvolume snapshot /mnt1/ /mnt1/snap
	RET=$?
	assert_warn $RET 0 "Creating and copying subvolume and snapshot. Iteration: $z of  $ITERATIONS"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1
	sleep 10

	# CHECKSUM_SNAP=`find /mnt1/snap  -type f -print0 | xargs -0 md5sum | md5sum -b`
	# checksumming does not work ...

	SIZE_SNAP=`du -ks /mnt1/snap | awk '{print $1}'`

	## [ $CHECKSUM_SOURCE -eq $CHECKSUM_SNAP ]

	[ $SIZE_SOURCE -eq $SIZE_SNAP ]
	RET=$?
	assert_warn $RET 0 "Filesystem size of source: $SIZE_SOURCE. Filesystem size of snap: $SIZE_SNAP"
	# [ $RET != 0 ] && end_section 0 && clean_up && exit 1
	[ $RET != 0 ] && end_section 0 && exit 1

	# Before removing the snapshot we do a filesystem snc
	# btrfsctl -c $MOUNTDEV /mnt1
	btrfs filesystem sync /mnt1
	RET=$?
	assert_warn $RET 0 "Syncing filesystem on RAID10 cluster. Iteration: $z of  $ITERATIONS"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1
	sleep 2

	# Remove the snapshot again
	# btrfsctl -D snap /mnt1
	btrfs subvolume delete /mnt1/snap
	RET=$?
	assert_warn $RET 0 "Removing snapshot on RAID10"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1

	# Now let's try some btrfs commands
	# Removing a device and adding it again

	# Show space of fs
	btrfs filesystem df /mnt1
	RET=$?
	assert_warn $RET 0 "Show space on RAID10 cluster filesystem"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1

	# Before we remove the data on the disks otherwise it might happen that not eough space is availabe
	# rm -rf /mnt1/*
	#        RET=$?
	#        assert_warn $RET 0 "Deleting all files from RAID10 cluster on /mnt1  Iteration: $z of  $ITERATIONS"
	#                [ $RET != 0 ] && end_section 0 && clean_up && exit 1

	DELETE_DEVNO=`echo $DASDS | awk '{print $2}'`

	for (( i = 1; i <= 5; i++ )); do
	btrfs device delete $DELETE_DEVNO-part1 /mnt1
	RET=$?
	assert_warn $RET 0 "Removing device $DELETE_DEVNO-part1 from RAID10 array for the $i. time. Iteration: $z of  $ITERATIONS"
	# [ $RET != 0 ] && end_section 0 && clean_up && exit 1
	[ $RET != 0 ] && end_section 0 && exit 1
	sleep 5
	btrfs device add $DELETE_DEVNO-part1 /mnt1
	RET=$?
	assert_warn $RET 0 "Adding device $DELETE_DENO-part1 from RAID10 array for the $i. time. Iteration: $z of $ITERATIONS"
	[ $RET != 0 ] && end_section 0 && clean_up && exit 1
	sleep 1

	btrfs filesystem balance /mnt1
	sleep 5

	# Check whether all devnos have been used in the array
	[ `btrfs filesystem show | grep -v dasda | grep -c devid` -eq `echo $DEVNOS | wc -w` ]
	RET=$?
	assert_warn $RET 0 "DASDs still complete after removing/adding. Iteration: $z of $ITERATIONS"
	#		        [ $RET != 0 ] && end_section 0 && clean_up && exit 1
	#	done
	#
done
umount /mnt1
clean_up
done
exit
