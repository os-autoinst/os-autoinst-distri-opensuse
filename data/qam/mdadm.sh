#!/bin/bash

# check if in /var/tmp is at least 2048 MB of free disk space
AVAILABLE_DISK_SPACE=$(df -m /var/tmp|awk '{print$4}'|grep [[:digit:]])
if [ "$AVAILABLE_DISK_SPACE" -lt "2048"  ]; then
    echo "At leat 2G of disk space in /var/tmp is needed, free disk space or modify script"
    exit 1
fi

MD_DEVICE=/dev/md1054

DEV_1=/dev/loop41
DEV_2=/dev/loop42
DEV_3=/dev/loop43

IMAGE_SIZE=536870912 # 512 MiB
RANDOM_DATA_COPY_COUNT=4

LANG=C

TEMP_ROOT=/var/tmp/mdadm_test
tempdir=$TEMP_ROOT/$RANDOM
tempmnt=$tempdir/mnt

# echo command to log and exit on error
function run
{
  echo "# $@"
  $@ || exit 1
}

# echo command to log, check for pattern in output and exit on error or pattern not found
function rungrep
{
  pattern=$1
  shift

  echo "# $@"
  output=$($@ || exit 1)

  echo "$output"
  echo "$output" | grep -Eq "$pattern"

  if [ ! $? = 0 ]
  then
    echo "Expected pattern \"$pattern\" not found!"
    exit 1
  fi
}

function rungrepdebug
{
  pattern=$1
  shift

  echo "# $@"
  output=$($@ || exit 1)

  echo "$output" | grep -E "$pattern"
}

function passed
{
  echo ""
  echo "==> PASSED"
  echo ""
}

function breakdown
{
  echo ""
  echo "Test Breakdown:"
  echo "---------------"
  echo ""

  run cd $HOME
  rungrepdebug "/dev/loop42" lsof

  # safety, in case we got interrupted halfway through
  mount | grep -F $tempmnt && umount $tempmnt
  if [ -e $MD_DEVICE ] ; then mdadm --stop $MD_DEVICE ; fi
  for i in 1 2 3 ; do if losetup $(eval echo \$DEV_$i) >/dev/null 2>&1 ; then run losetup -d $(eval echo \$DEV_$i) ; fi ; done

  run rm -rf $TEMP_ROOT /var/tmp/mdadm.sh.conf

  echo ""
  echo "$result"
  echo ""
}

echo ""
echo "Test Setup:"
echo "-----------"
echo ""

run mkdir -p $tempdir
run mkdir -p $tempmnt

run cd $tempdir

result="FAILED on $(uname -a)"

# only set the trap after the initial creation of the folders is done
trap breakdown SIGTERM EXIT

run which mdadm
run mdadm --version
run rpm -q mdadm

# make sure the md device we want to use is not already used by the system under test
if [ -e $MD_DEVICE ]
then
  echo "Device $MD_DEVICE already in use. Please change the MD_DEVICE variable in this script and try again."
  exit 1
fi

for i in 1 2 3
do
  if losetup $(eval echo \$DEV_$i) >/dev/null 2>&1
  then
    echo "Device $(eval echo \$DEV_$i) already in use. Please change the DEV_$i variable in this script and try again."
    exit 1
  fi
done

echo ""
echo "Test 1: RAID 0"
echo "--------------"
echo ""

result="FAILED Test 1 on $(uname -a)"

for i in 1 2 3
do
  echo "Creating disk image $i of size $(($IMAGE_SIZE/1048576))MiB ..."
  run fallocate -l $IMAGE_SIZE disk$i.img
done

echo "Done!"

run losetup $DEV_1 disk1.img
run losetup $DEV_2 disk2.img
run losetup $DEV_3 disk3.img

run losetup -l

run mdadm --create --verbose $MD_DEVICE --level=0 --raid-devices=3 --size=522240 $DEV_1 $DEV_2 $DEV_3

rungrep "active raid0" cat /proc/mdstat

# Different fdisk versions either report "1.5 GiB" or "1.49 GiB"
rungrep "1.(5|49) GiB" fdisk -l $MD_DEVICE

rungrep "Creating filesystem with" mkfs.ext4 $MD_DEVICE

run mount $MD_DEVICE $tempmnt
mount | grep -F -q $tempmnt || exit 1

run dd if=/dev/urandom of=random_data.raw bs=100M count=1

random_md5=$(md5sum random_data.raw | cut -d" " -f1)
echo "$random_md5  random_data.raw"

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  echo "Copying random file $i ..."
  run cp random_data.raw $tempmnt/random_$i.raw
done 

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run umount $MD_DEVICE
run mdadm --detail --scan >/var/tmp/mdadm.sh.conf
run mdadm --stop $MD_DEVICE
run mdadm --assemble --scan --config=/var/tmp/mdadm.sh.conf
run mount $MD_DEVICE $tempmnt
mount | grep -F -q $tempmnt || exit 1

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run umount $MD_DEVICE
run mdadm --stop $MD_DEVICE
run losetup -d $DEV_1 $DEV_2 $DEV_3
run rm -f disk1.img disk2.img disk3.img random_data.raw

passed

echo "Test 2: RAID 1"
echo "--------------"
echo ""

result="FAILED Test 2 on $(uname -a)"

for i in 1 2 3
do
  echo "Creating disk image $i of size $(($IMAGE_SIZE/1048576))MiB ..."
  run fallocate -l $IMAGE_SIZE disk$i.img
done

echo "Done!"

run losetup $DEV_1 disk1.img
run losetup $DEV_2 disk2.img
run losetup $DEV_3 disk3.img

run losetup -l

run yes | mdadm --create --verbose $MD_DEVICE --level=1 --raid-devices=3 --size=522240 $DEV_1 $DEV_2 $DEV_3

sleep 1
rungrep "active raid1" cat /proc/mdstat

count=0
until grep "UUU" /proc/mdstat; do
  echo "Waiting for raid sync ..."
  sleep 5
  # avoid endless loop
  (( count++ ))
  if [ $count == 20 ]; then
    echo "Waiting too long for raid to sync!"
    break
  fi
done

rungrep "UUU" cat /proc/mdstat

rungrep "510 MiB" fdisk -l $MD_DEVICE

rungrep "Creating filesystem with" mkfs.ext4 $MD_DEVICE

run mount $MD_DEVICE $tempmnt
mount | grep -F -q $tempmnt || exit 1

run dd if=/dev/urandom of=random_data.raw bs=100M count=1

random_md5=$(md5sum random_data.raw | cut -d" " -f1)
echo "$random_md5  random_data.raw"

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  echo "Copying random file $i ..."
  run cp random_data.raw $tempmnt/random_$i.raw
done 

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run mdadm $MD_DEVICE --fail $DEV_2

rungrep "clean, degraded" mdadm --detail $MD_DEVICE | grep -F "State :"

rungrep "\[1\]\(F\)" cat /proc/mdstat

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

count=0
until mdadm --detail $MD_DEVICE|grep "removed"; do
  echo "Waiting until faulty device is removed from raid ..."
  sleep 5
  # avoid endless loop
  (( count++ ))
  if [ $count == 20 ]; then
    echo "Waiting too long to remove device!"
    break
  fi
done

run mdadm $MD_DEVICE --remove $DEV_2

rungrep "U_U" cat /proc/mdstat

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run losetup -d $DEV_2
run rm disk2.img
run sync
run fallocate -l $IMAGE_SIZE disk2.img

run losetup $DEV_2 disk2.img
run mdadm --add $MD_DEVICE $DEV_2

sleep 1
rungrep "U_U" cat /proc/mdstat

count=0
until grep "UUU" /proc/mdstat; do
  echo "Waiting for raid sync ..."
  sleep 5
  # avoid endless loop
  (( count++ ))
  if [ $count == 20 ]; then
    echo "Waiting too long for raid to sync!"
    break
  fi
done

rungrep "UUU" cat /proc/mdstat

rungrep "clean" mdadm --detail $MD_DEVICE | grep -F "State :"

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run umount $MD_DEVICE
run mdadm --detail --scan > /var/tmp/mdadm.sh.conf
run mdadm --stop $MD_DEVICE
run mdadm --assemble --scan --config=/var/tmp/mdadm.sh.conf
run mount $MD_DEVICE $tempmnt
mount | grep -F -q $tempmnt || exit 1

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run umount $MD_DEVICE
run mdadm --stop $MD_DEVICE
run losetup -d $DEV_1 $DEV_2 $DEV_3
run rm -f disk1.img disk2.img disk3.img random_data.raw

passed

echo "Test 3: RAID 5"
echo "--------------"
echo ""

result="FAILED Test 3 on $(uname -a)"

for i in 1 2 3
do
  echo "Creating disk image $i of size $(($IMAGE_SIZE/1048576))MiB ..."
  run fallocate -l $IMAGE_SIZE disk$i.img
done

echo "Done!"

run losetup $DEV_1 disk1.img
run losetup $DEV_2 disk2.img
run losetup $DEV_3 disk3.img

run losetup -l

run mdadm --create --verbose $MD_DEVICE --level=5 --raid-devices=3 --size=522240 $DEV_1 $DEV_2 $DEV_3

sleep 1
rungrep "active raid5" cat /proc/mdstat

count=0
until grep "UUU" /proc/mdstat; do
  echo "Waiting for raid sync ..."
  sleep 5
  # avoid endless loop
  (( count++ ))
  if [ $count == 20 ]; then
    echo "Waiting too long for raid to sync!"
    break
  fi
done

rungrep "UUU" cat /proc/mdstat

rungrep "1020 MiB" fdisk -l $MD_DEVICE

rungrep "Creating filesystem with" mkfs.ext4 $MD_DEVICE

run mount $MD_DEVICE $tempmnt
mount | grep -F -q $tempmnt || exit 1

run dd if=/dev/urandom of=random_data.raw bs=100M count=1

random_md5=$(md5sum random_data.raw | cut -d" " -f1)
echo "$random_md5  random_data.raw"

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  echo "Copying random file $i ..."
  run cp random_data.raw $tempmnt/random_$i.raw
done 

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run mdadm $MD_DEVICE --fail $DEV_1

rungrep "clean, degraded" mdadm --detail $MD_DEVICE | grep -F "State :"

rungrep "\[0\]\(F\)" cat /proc/mdstat

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run mdadm $MD_DEVICE --remove $DEV_1

rungrep "_UU" cat /proc/mdstat

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run losetup -d $DEV_1
run rm disk1.img
run sync
run fallocate -l $IMAGE_SIZE disk1.img

run losetup $DEV_1 disk1.img
run sync
run mdadm --add $MD_DEVICE $DEV_1

sleep 1
rungrep "_UU" cat /proc/mdstat

count=0
until grep "UUU" /proc/mdstat; do
  echo "Waiting for raid sync ..."
  sleep 5
  # avoid endless loop
  (( count++ ))
  if [ $count == 20 ]; then
    echo "Waiting too long for raid to sync!"
    break
  fi
done

rungrep "UUU" cat /proc/mdstat

rungrep "clean" mdadm --detail $MD_DEVICE | grep -F "State :"

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done

run umount $MD_DEVICE
run mdadm --detail --scan > /var/tmp/mdadm.sh.conf
run mdadm --stop $MD_DEVICE
run mdadm --assemble --scan --config=/var/tmp/mdadm.sh.conf
run mount $MD_DEVICE $tempmnt
mount | grep -F -q $tempmnt || exit 1

for i in $(seq -w 1 $RANDOM_DATA_COPY_COUNT)
do
  rungrep "$random_md5" md5sum $tempmnt/random_$i.raw
done
run umount $MD_DEVICE

passed

result="==> all tests PASSED"

exit 0
