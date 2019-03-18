# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 10_Pre_Ipl_Tests.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done

isVM
if [[ $? -eq 0 ]];then
start_section 1 "10.11 Pre Ipl GCCW"
  if grep -q 120_GCCW omit; then
    assert_exec 0 "echo 'omitting 120_GCCW'"
  else
    #device offline and displayed as persistent offline and active offline?
    lszdev $GCCW --online | grep $GCCW | grep yes
    assert_warn $? 1 "Active configuration offline"

    lszdev $GCCW --configured | grep $GCCW
    assert_warn $? 1 "Persistent configuration offline"

    lscss | grep ' 1403/00' |grep 000e | grep yes | grep $GCCW
    assert_fail $? 1 "GCCW $GCCW is offline"
    #enable device persistent/active
    assert_exec 0 "chzdev $GCCW -e -V"
    #device online and displayed as persistent online and active online?
    lscss | grep ' 1403/00' | grep $GCCW | grep yes
    assert_fail $? 0 "GCCW $GCCW is online"

    lszdev $GCCW --online | grep $GCCW
    assert_warn $? 0 "Active configuration online"

    lszdev $GCCW --configured | grep $GCCW
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)
    assert_exec 0 "chzdev $GCCW cmb_enable=1"
    lszdev $GCCW -i | grep cmb_enable | grep 1
    assert_warn $? 0 "cmb_enable=1"
    #save configuration
    assert_exec 0 "chzdev $GCCW --export gccw.conf"
    #device active off
    assert_exec 0 "chzdev $GCCW -d -a -V"
    #device offline and displayed as persistent online and active offline?
    lscss | grep ' 1403/00' |grep $GCCW | grep yes
    assert_fail $? 1 "GCCW $GCCW is offline"

    lszdev $GCCW --online | grep $GCCW
    assert_warn $? 1 "Active configuration offline"

    lszdev $GCCW --configured | grep $GCCW
    assert_warn $? 0 "Persistent configuration online"
    #apply persistent configuration
    assert_exec 0 "chzdev $GCCW --apply"
    #device online and displayed as persistent online and active online?
    lscss | grep ' 1403/00' |grep $GCCW | grep yes
    assert_fail $? 0 "GCCW $GCCW is online"

    lszdev $GCCW --online | grep $GCCW
    assert_warn $? 0 "Active configuration online"

    lszdev $GCCW --configured | grep $GCCW
    assert_warn $? 0 "Persistent configuration online"
  fi
end_section 1
fi

start_section 1 "10.12 Pre Ipl root Device"
  #depends on initrd

      assert_exec 0 "ls /boot | grep -q initrd"

  if [[ $? -ne 0 ]];then
    assert_exec 0 "chzdev --by-path / -e -V"
    #persistent online and active online?
    lszdev --by-path / --online
    assert_warn $? 0 "Active configuration online"

    lszdev --by-path / --configured
    assert_warn $? 0 "Persistent configuration online"

    assert_exec 0 "chzdev $DASD expires=31"
    lszdev $DASD -i | grep expires | grep 31
    assert_warn $? 0 "expires=31"

  fi
  #change device driver configuration (#2) (needs to be done pre reboot)
  #depends on patch not yet in distro
  assert_exec 0 "chzdev dasd --type -p -y -f eer_pages=6 nopav=1 nofcx=1 autodetect=1"

end_section 1

start_section 1 "10.13 Basic tests for covarage"

  assert_exec 0 "chzdev --help >> /dev/null"
  assert_exec 0 "lszdev --help >> /dev/null"

  assert_exec 0 "chzdev -v >> /dev/null"
  assert_exec 0 "lszdev -v >> /dev/null"

  assert_exec 0 "chzdev zfcp -l >> /dev/null"
  assert_exec 0 "chzdev dasd -l >> /dev/null"
  assert_exec 0 "chzdev dasd-eckd -l >> /dev/null"
  assert_exec 0 "chzdev dasd-fba -l >> /dev/null"
  assert_exec 0 "chzdev zfcp-host -l >> /dev/null"
  assert_exec 0 "chzdev zfcp-lun -l >> /dev/null"
  assert_exec 0 "chzdev qeth -l >> /dev/null"
  assert_exec 0 "chzdev ctc -l >> /dev/null"
  assert_exec 0 "chzdev lcs -l >> /dev/null"
  assert_exec 0 "chzdev generic-ccw -l >> /dev/null"

  assert_exec 0 "lszdev -l >> /dev/null"

  assert_exec 0 "chzdev -L >> /dev/null"
  assert_exec 0 "lszdev -L >> /dev/null"

  assert_exec 0 "chzdev zfcp -H >> /dev/null"
  assert_exec 0 "chzdev dasd -H >> /dev/null"
  assert_exec 0 "chzdev dasd-eckd -H >> /dev/null"
  assert_exec 0 "chzdev dasd-fba -H >> /dev/null"
  assert_exec 0 "chzdev zfcp-host -H >> /dev/null"
  assert_exec 0 "chzdev zfcp-lun -H >> /dev/null"
  assert_exec 0 "chzdev qeth -H >> /dev/null"
  assert_exec 0 "chzdev ctc -H >> /dev/null"
  assert_exec 0 "chzdev lcs -H >> /dev/null"
  assert_exec 0 "chzdev generic-ccw -H >> /dev/null"

  assert_exec 0 "chzdev zfcp -H scsi_dev/state >> /dev/null"

end_section 1