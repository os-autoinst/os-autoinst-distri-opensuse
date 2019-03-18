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
start_section 1 "10.3 Pre Ipl dasd-fba"

  if grep -q 40_DASD_FBA omit; then
    assert_exec 0 "echo 'omitting 30_DASD_FBA'"
  else

    #device offline and displayed as persistent offline and active offline?
    lszdev $DASD_FBA --online | grep $DASD_FBA
    assert_warn $? 1 "Active configuration offline"

    lszdev $DASD_FBA --configured | grep $DASD_FBA
    assert_warn $? 1 "Persistent configuration offline"

    lsdasd | grep $DASD_FBA
    assert_fail $? 1 "DASD_FBA $DASD_FBA is offline"
    #enable device persistent/active
    assert_exec 0 "chzdev dasd-fba $DASD_FBA -e -V"
    #device online and displayed as persistent online and active online?
    lsdasd | grep $DASD_FBA
    assert_fail $? 0 "DASD_FBA $DASD_FBA is online"

    lszdev $DASD_FBA --online | grep $DASD_FBA
    assert_warn $? 0 "Active configuration online"

    lszdev $DASD_FBA --configured | grep $DASD_FBA
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)

    assert_exec 0 "chzdev $DASD_FBA erplog=1"
    lszdev $DASD_FBA -i | grep erplog | grep 1
    assert_warn $? 0 "erplog=1"

    assert_exec 0 "chzdev $DASD_FBA expires=31"
    lszdev $DASD_FBA -i | grep expires | grep 31
    assert_warn $? 0 "expires=31"

    assert_exec 0 "chzdev $DASD_FBA failfast=1"
    lszdev $DASD_FBA -i | grep failfast | grep 1
    assert_warn $? 0 "failfast=1"

    assert_exec 0 "chzdev $DASD_FBA readonly=1"
    lszdev $DASD_FBA -i | grep readonly | grep 1
    assert_warn $? 0 "readonly=1"

    #depends on patch not yet in distro
    if [[ $? -eq 0 ]];then
      assert_exec 0 "chzdev $DASD_FBA timeout=999"
      lszdev $DASD_FBA -i | grep timeout | grep 999
      assert_warn $? 0 "timeout=999"

      assert_exec 0 "chzdev $DASD_FBA retries=999"
      lszdev $DASD_FBA -i | grep retries | grep 999
      assert_warn $? 0 "retries=999"
    fi
    assert_exec 0 "chzdev $DASD_FBA reservation_policy=fail"
    lszdev $DASD_FBA -i | grep reservation_policy | grep fail
    assert_warn $? 0 "reservation_policy=fail"
    #save configuration
    assert_exec 0 "chzdev $DASD_FBA --export dasd-fba.conf"

    #device active off
    assert_exec 0 "chzdev $DASD_FBA -d -a -V"

    #more configuration which only works if device is offline
    isVM
    if [[ $? -eq 1 ]];then
      chzdev $DASD_FBA use_diag=1
      assert_warn $? 9 "use_diag should only be available on z/VM"
      else
      assert_exec 0 "chzdev $DASD_FBA use_diag=1"
      lszdev $DASD_FBA -i | grep use_diag | grep 1
      assert_warn $? 0 "use_diag=1"
      #cant be set online while usediag=1
      assert_exec 0 "chzdev $DASD_FBA use_diag=0"
      lszdev $DASD_FBA -i | grep use_diag | awk '{print $2}' | grep 0
      assert_warn $? 0 "use_diag=0"
    fi

    #device offline and displayed as persistent online and active offline?
    lsdasd | grep $DASD_FBA
    assert_fail $? 1 "DASD_FBA $DASD_FBA is offline"

    lszdev $DASD_FBA --online | grep $DASD_FBA
    assert_warn $? 1 "Active configuration offline"

    lszdev $DASD_FBA --configured | grep $DASD_FBA
    assert_warn $? 0 "Persistent configuration online"
    #apply persistent configuration
    assert_exec 0 "chzdev $DASD_FBA --apply"
    #device online and displayed as persistent online and active online?
    lsdasd | grep $DASD_FBA
    assert_fail $? 0 "DASD_FBA $DASD_FBA is online"

    lszdev $DASD_FBA --online | grep $DASD_FBA
    assert_warn $? 0 "Active configuration online"

    lszdev $DASD_FBA --configured | grep $DASD_FBA
    assert_warn $? 0 "Persistent configuration online"
  fi
end_section 1
fi


start_section 1 "10.4 Pre Ipl ZFCP_H"

  if grep -q 50_ZFCP_H omit; then
    assert_exec 0 "echo 'omitting 50_ZFCP_H'"
  else

    #device offline and displayed as persistent offline and active offline?
    lszdev $ZFCP_H --online | grep $ZFCP_H
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_H --configured | grep $ZFCP_H
    assert_warn $? 1 "Persistent configuration offline"

    lszfcp -P | grep $ZFCP_H
    assert_fail $? 1 "ZFCP_H $ZFCP_H is offline"
    #enable device persistent/active
    assert_exec 0 "chzdev zfcp $ZFCP_H -e -V"
    #device online and displayed as persistent online and active online?
    lszfcp -P | grep $ZFCP_H
    assert_fail $? 0 "ZFCP_H $ZFCP_H is online"

    lszdev $ZFCP_H --online | grep $ZFCP_H
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_H --configured | grep $ZFCP_H
    assert_warn $? 0 "Persistent configuration online"
    #device active off
    assert_exec 0 "chzdev $ZFCP_H -d -a -V"
    #device offline and persistent offline and active offline?
    lszfcp -P | grep $ZFCP_H
    assert_fail $? 1 "ZFCP_H $ZFCP_H offline"

    lszdev $ZFCP_H --online | grep $ZFCP_H
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_H --configured | grep $ZFCP_H
    assert_warn $? 0 "Persistent configuration online"
    #apply persistent configuration
    assert_exec 0 "chzdev $ZFCP_H --apply"
    #save configuration
    assert_exec 0 "chzdev $ZFCP_H --export zfcp-h.conf"
    #device online and displayed as persistent online and active online?
    lszfcp -P | grep $ZFCP_H
    assert_fail $? 0 "ZFCP_H $ZFCP_H is online"

    lszdev $ZFCP_H --online | grep $ZFCP_H
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_H --configured | grep $ZFCP_H
    assert_warn $? 0 "Persistent configuration online"

    #change device configuration (#1)
    assert_exec 0 "chzdev $ZFCP_H cmb_enable=0 -p"
    lszdev $ZFCP_H -i | grep cmb_enable | grep 0
    assert_warn $? 0 "cmb_enable=0"
  fi
end_section 1



start_section 1 "10.5 Pre Ipl ZFCP_L"

  if grep -q 60_ZFCP_L omit; then
    assert_exec 0 "echo 'omitting 60_ZFCP_L'"
  else

    LUN="$( cut -d ':' -f 3 <<< "$ZFCP_L" )";
    #device offline and displayed as persistent offline and active offline?
    lszdev $ZFCP_L --online | grep $ZFCP_L
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_L --configured | grep $ZFCP_L
    assert_warn $? 1 "Persistent configuration offline"

    lsluns -a | grep $LUN
    assert_fail $? 1 "ZFCP_L $ZFCP_L is offline"
    #enable device persistent/active
    assert_exec 0 "chzdev zfcp $ZFCP_L -e -V"
    #device online and displayed as persistent online and active online?
    lsluns -a | grep $LUN
    assert_fail $? 0 "ZFCP_L $ZFCP_L is online"

    lszdev $ZFCP_L --online | grep $ZFCP_L
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_L --configured | grep $ZFCP_L
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)
    assert_exec 0 "chzdev $ZFCP_L scsi_dev/queue_depth=33"
    lszdev $ZFCP_L -i | grep scsi_dev/queue_depth | grep 33
    assert_warn $? 0 "scsi_dev/queue_depth=33"

    assert_exec 0 "chzdev $ZFCP_L scsi_dev/timeout=33"
    lszdev $ZFCP_L -i | grep scsi_dev/timeout | grep 33
    assert_warn $? 0 "scsi_dev/timeout=33"
    #save configuration
    assert_exec 0 "chzdev $ZFCP_L --export zfcp-l.conf"
    #device active off
    assert_exec 0 "chzdev $ZFCP_L -d -a -V"
    #device offline and displayed as persistent online and active offline?
    lsluns -a | grep $LUN
    assert_fail $? 1 "ZFCP_L $ZFCP_L is offline"

    lszdev $ZFCP_L --online | grep $ZFCP_L
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_L --configured | grep $ZFCP_L
    assert_warn $? 0 "Persistent configuration online"
    #apply persistent configuration
    assert_exec 0 "chzdev $ZFCP_L --apply"
    #device online and displayed as persistent online and active online?
    lsluns -a | grep $LUN
    assert_fail $? 0 "ZFCP_L $ZFCP_L is online"

    lszdev $ZFCP_L --online | grep $ZFCP_L
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_L --configured | grep $ZFCP_L
    assert_warn $? 0 "Persistent configuration online"
  fi
end_section 1

start_section 1 "10.6 Pre Ipl ZFCP_HOST"

  if grep -q 70_ZFCP_HOST omit; then
    assert_exec 0 "echo 'omitting 60_ZFCP_HOST'"
  else

    #device offline and displayed as persistent offline and active offline?
    lszdev $ZFCP_HOST --online | grep $ZFCP_HOST
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_HOST --configured | grep $ZFCP_HOST
    assert_warn $? 1 "Persistent configuration offline"

    lszfcp -P | grep $ZFCP_HOST
    assert_fail $? 1 "ZFCP_HOST $ZFCP_HOST is offline"
    #enable device persistent/active
    assert_exec 0 "chzdev zfcp $ZFCP_HOST -e -V"
    #device online and displayed as persistent online and active online?
    lszfcp -P | grep $ZFCP_HOST
    assert_fail $? 0 "ZFCP_HOST $ZFCP_HOST is online"

    lszdev $ZFCP_HOST --online | grep $ZFCP_HOST
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_HOST --configured | grep $ZFCP_HOST
    assert_warn $? 0 "Persistent configuration online"
    #device active off
    assert_exec 0 "chzdev $ZFCP_HOST -d -a -V"

    #device offline and displayed as persistent online and active offline?
    lszfcp -P | grep $ZFCP_HOST
    assert_fail $? 1 "ZFCP_HOST $ZFCP_HOST offline"

    lszdev $ZFCP_HOST --online | grep $ZFCP_HOST
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_HOST --configured | grep $ZFCP_HOST
    assert_warn $? 0 "Persistent configuration online"
    #apply persistent configuration
    assert_exec 0 "chzdev $ZFCP_HOST --apply"
    #save configuration
    assert_exec 0 "chzdev $ZFCP_HOST --export zfcp-host.conf"
    #device online and displayed as persistent online and active online?
    lszfcp -P | grep $ZFCP_HOST
    assert_fail $? 0 "ZFCP_HOST $ZFCP_HOST is online"

    lszdev $ZFCP_HOST --online | grep $ZFCP_HOST
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_HOST --configured | grep $ZFCP_HOST
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)
    assert_exec 0 "chzdev $ZFCP_HOST cmb_enable=0 -p"
    lszdev $ZFCP_HOST -i | grep cmb_enable | grep 0
    assert_warn $? 0 "cmb_enable=0"
  fi
end_section 1