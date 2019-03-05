# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

#####################
# CLEAN UP FUNCTIONS
#####################

_un_mount_LVs(){

  # $1 lvname
  assert_exec 0 "umount  /mnt/$1"; echo;
  assert_fail $? 0 "unmount successful"; echo;
  sleep 2

}

_lv_clean(){

  # $1 lvpath
  #lv=""
  #vg=""
  #vg=`vgdisplay | grep "VG Name" | awk -F " " '{ printf $3 }'`
  #lv=`lvdisplay | grep "LV Name" | awk -F " " '{ printf $3 }'`
  assert_exec 0 "lvremove $1 -f"; echo;
  sleep 2
  assert_exec 0 "lvscan; vgscan; lvdisplay"; echo;
  echo "lvdisplay | grep $1"
  lvdisplay | grep $1
  RET=$?
  assert_warn $RET 1 "`date` logical volume $1 is removed from lvm"
  [ $RET != 1 ] && end_section 1 && _clean_up && exit 1


}

_vg_clean(){

  # $1 vgname
  #vg=""
  #vg=`vgdisplay | grep "VG Name" | awk -F " " '{ printf $3 }'`
  assert_exec 0 "vgremove $1"; echo;
  sleep 2
  assert_exec 0 "pvscan; vgscan; vgdisplay"; echo;
  vgdisplay | grep $1
  RET=$?
  assert_warn $RET 1 "`date` Volume group $1 is removed from lvm"
  [ $RET != 1 ] && end_section 1 && _clean_up && exit 1
}

_pv_clean(){

  PV=""
  #PVS=`pvscan | grep -e /dev/ | awk '{print $2}'`
  PVS=`pvscan | grep -v VG | awk -F " " '{print $2}'`
  for PV in $PVS ;do
    assert_exec 0 "pvremove $PV --force"; echo;sleep 2;
    assert_exec 0 "pvscan";
    pvscan | grep $PV
    RET=$?
    assert_warn $RET 1 "`date` physical volume $PV is removed from lvm"
    [ $RET != 1 ] && end_section 1 && _clean_up && exit 1
  done


}

_clean_up(){

  for DEVNO in $1;do
    deactivate_dasd $DEVNO
  done

  sleep 5
}

_cleanup_all(){

  _un_mount_LVs
  _lv_clean
  _vg_clean
  _pv_clean
  _clean_up
}

_init_lvm_check(){

  umount -l /mnt/*

  lv=""
  vg=""
  pv=""

  # clean up the existing LVM stuff

  lvchange -an

  for lv in `lvdisplay |grep "LV Path" |cut -f 3-9 -d "/"`; do
    echo "removing Logical Volume $lv"
    lvremove -ff -v $lv
  done

  vgchange -an

  for vg in `vgdisplay |grep "VG Name" |awk '{print $3}'`; do
    echo "removing Volume Group $vg"
    vgremove -ff -v $vg
  done

  for pv in `pvdisplay |grep "PV Name" |awk '{print $3}'`; do
    echo "removing Physical Volume $pv"
    pvremove -ff -v $pv
  done

  echo lvdisplay
  lvdisplay

  echo vgdisplay
  vgdisplay

  echo pvdisplay
  pvdisplay

}
