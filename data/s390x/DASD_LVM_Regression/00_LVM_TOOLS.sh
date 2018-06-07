# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

#############################################################
## NAME : LOGICAL VOLUME MANAGER TOOLS
#############################################################

DEVELOPMENTMODE="yes"

############################
## INCLUDING THE LIB SCRIPTS
############################
for f in lib/*.sh; do source $f; done
source ./00_LVM_TOOLS_1.sh || exit 1
#############################
## DEFINING FUNCTIONS TO USE
#############################
PARTITIONS=""
DASD_BASE=""


_init_dasd_setup(){

  # Prepare HPAV BASE
  # Make sure at least 1 base is online before making alias online
  for DEV in $BASE_PAV $ALIAS_PAV;do
    DEVNO=`echo $DEV | tr '[:upper:]' '[:lower:]'`
    echo "activate_dasd $DEVNO"
    activate_dasd $DEVNO
    RET=$?
    assert_warn $RET 0 "`date` Online $DEVNO"
    [ $RET != 0 ] && echo "make sure at least one base is online or the alias is choosen incorrectly !" && end_section 0 && exit 1
    sleep 2



    _isbase $DEVNO
    if [ $alias == 0 ];
    then

      if [ $? == 0 ];
      then
        # BASE="`basename /sys/bus/ccw/drivers/dasd-eckd/0.0.$DEVNO/block\:* | cut -c7-12`"
        BASE=$(ls /sys/bus/ccw/drivers/dasd-eckd/0.0.$DEVNO/block)
        echo vk_base: $BASE
      else
        BASE=`basename /sys/bus/ccw/drivers/dasd-eckd/0.0.$DEVNO/block/*`
      fi
      #format the device if not in proper format
      is_unformatted $DEVNO
      if [ $RET == 0 ];
      then
        echo "format_dasd_bus_id cdl 4096 $DEVNO"
        format_dasd cdl 4096 $DEVNO
        RET=$?
        assert_warn $RET 0 "`date` Format $DEVNO"
        [ $RET != 0 ] && end_section 0 && exit 1
        sleep 2
      else
        echo "Device is in proper format, no need to format again !"
      fi

      fdasd_dasd $DEVNO
      RET=$?
      assert_warn $RET 0 "`date` Creation of partition on DASD $DEVNO"
      [ $RET != 0 ] && end_section 0 && exit 1
      sleep 2

      PARTITIONS="/dev/disk/by-path/ccw-0.0.$DEVNO-part1 $PARTITIONS"
      DASD_BASE="$BASE $DASD_BASE"

    fi
  done
  echo BASES: $DASD_BASE; echo;
  echo PARTS: $PARTITIONS; echo;
}

_create_PVs(){

  PART=""
  for PART in $PARTITIONS;do
    assert_exec 0 "pvcreate -ff --yes $PART"; echo;
    sleep 2
    assert_exec 0 "pvscan"; echo;
    assert_exec 0 "pvdisplay"; echo;
  done
  for BASE in $DASD_BASE;do
    echo "pvscan | grep $BASE"
    pvscan | grep $BASE
    RET=$?
    assert_warn $RET 0 "`date` physical volume /dev/"$BASE"1 created"
    [ $RET != 0 ] && end_section 1 && _clean_up && exit 1
  done
}

_create_VGs(){

  # $1 vgname $2 $PARTITIONS
  assert_exec 0 "vgcreate -f $1 $PARTITIONS"; echo;
  sleep 2
  assert_exec 0 "pvscan; vgscan; vgdisplay"; echo;
  echo "vgdisplay | grep $1"
  vgdisplay | grep $1
  RET=$?
  assert_warn $RET 0 "`date` Volume group $1 created"
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1
}

_create_linear_LVs(){

  size=""
  size=`vgdisplay | grep "VG Size" | awk -F " " '{ printf $3 }' | cut -f 1 -d "."`
  echo "lvcreate --yes -L "$size"G -n test_linear_lv0 $1"
  assert_exec 0 "lvcreate --yes -L "$size"G -n test_linear_lv0 $1"; echo;
  sleep 2
  assert_exec 0 "lvscan;lvdisplay"; echo;
  lvdisplay | grep test_linear_lv0
  RET=$?
  assert_warn $RET 0 "`date` Linear logical volume test_linear_lv0 is created"
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1
  echo "check for /dev/$1/ created"
  ls /dev/$1/*
  RET=$?
  assert_warn $RET 0 "`date` /dev/$1 directory is created"
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1


}

_create_mirror_LVs(){

  # $1 vgname
  echo "Creating a mirrored logical volumes with usable size of 500MB and out of 3 devices 1 will be used for logs";echo
  echo "lvcreate --yes -m1 -L 500M $1"
  assert_exec 0 "lvcreate --yes -m1 -L 500M $1"; echo;
  sleep 2
  assert_exec 0 "lvscan;lvdisplay"; echo;
  lvdisplay | grep $1
  RET=$?
  assert_warn $RET 0 "`date` Mirrored logical volume /dev/vg_mirrored/lvol0 is created"
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1
  echo "check for /dev/$1/ created"
  ls /dev/$1/*
  RET=$?
  assert_warn $RET 0 "`date` /dev/$1 directory is created"
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1


}
_create_striped_LVs(){

  # $1 vgname
  echo "Creating a striped logical volumes with 3 stripes stipesize of 8kb and size of 100MB";echo
  echo "lvcreate --yes -i 3 -I 8 -L 100M  $1"
  assert_exec 0 "lvcreate --yes -i 3 -I 8 -L 100M $1"; echo;
  sleep 2
  assert_exec 0 "lvscan;lvdisplay"; echo;
  lvdisplay | grep $1
  RET=$?
  assert_warn $RET 0 "`date` Striped logical volume /dev/vg_striped/lvol0 is created"
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1
  echo "check for /dev/$1/ created"
  ls /dev/$1/*
  RET=$?
  assert_warn $RET 0 "`date` /dev/$1 directory is created"
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1

}

_create_snapshot_LVs(){

  #$1=size
  lvname=""
  echo "Create snapshot lvs ...!"
  lvname=`lvdisplay  | grep "LV Path" |awk -F " " '{print $3}'`
  assert_exec 0 "lvcreate --yes -L"$1"G -s -n lvbackup $lvname";echo
  ls /dev/vg_linear/lvbackup
  RET=$?
  [ $RET != 0 ] && end_section 1 && _clean_up && exit 1
}

_create_fs_on_LVs(){

  # $1 LVs name
  assert_exec 0 "eval mkfs.ext3 $1"; echo;
  RET=$?
  assert_warn $RET 0 "`date` Creation of ext3 filesystem (mkfs.ext3) on logical volume $1"
  _wait_for_mkfs_ext3
  [ $RET != 0 ] && end_section 0 && _clean_up && exit 1
}

_wait_for_mkfs_ext3(){

  while [ `ps aux | grep -c mkfs.ext3` -gt 1 ]; do
    sleep 2
  done
  sleep 2
}

_mount_LVs(){

  # $1 vgname and $2 lvname

  mkdir /mnt/$2
  assert_exec 0 "mount $1  /mnt/$2"; echo;
  assert_fail $? 0 "Mount successful for $1 >> /mnt/$2"; echo;
  sleep 2
  assert_exec 0 "df -P /mnt/$2"

  LVS="$2 $LVS"
}

_init_IO(){

  dd if=/dev/urandom of=/mnt/linear/hugefile bs=4096
  RET=$?
  assert_warn $RET 1 "`date` IO test executed"
  [ $RET != 1 ] && end_section 0 && exit 1

}

is_unformatted(){
  echo "Check if the device is NOT formatted or LDL formatted"
  dasdview -x /dev/disk/by-path/ccw-0.0.$DEVNO | grep formatted |grep -v CDL
  RET=$?
}

_isbase(){

  alias=""
  echo "Checking if the device is a base"
  alias=`cat /sys/bus/ccw/devices/0.0.$1/alias`
  return $alias
}
