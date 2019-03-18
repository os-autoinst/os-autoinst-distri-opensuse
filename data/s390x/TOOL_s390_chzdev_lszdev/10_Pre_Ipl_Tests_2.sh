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

start_section 1 "10.7 Pre Ipl ZFCP_LUN"

  if grep -q 80_ZFCP_LUN omit; then
    assert_exec 0 "echo 'omitting 80_ZFCP_LUN'"
  else

    LUN="$( cut -d ':' -f 3 <<< "$ZFCP_LUN" )";
    #device offline and displayed as persistent offline and active offline?
    lszdev $ZFCP_LUN --online | grep $ZFCP_LUN
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_LUN --configured | grep $ZFCP_LUN
    assert_warn $? 1 "Persistent configuration offline"

    lsluns -a | grep $LUN
    assert_fail $? 1 "ZFCP_LUN $ZFCP_LUN is offline"
    #enable device persistent/active
    assert_exec 0 "chzdev zfcp $ZFCP_LUN -e -V"
    #device online and displayed as persistent online and active online?
    lsluns -a | grep $LUN
    assert_fail $? 0 "ZFCP_LUN $ZFCP_LUN is online"

    lszdev $ZFCP_LUN --online | grep $ZFCP_LUN
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_LUN --configured | grep $ZFCP_LUN
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)
    assert_exec 0 "chzdev $ZFCP_LUN scsi_dev/queue_depth=33"
    lszdev $ZFCP_LUN -i | grep scsi_dev/queue_depth | grep 33
    assert_warn $? 0 "scsi_dev/queue_depth=33"

    assert_exec 0 "chzdev $ZFCP_LUN scsi_dev/timeout=33"
    lszdev $ZFCP_LUN -i | grep scsi_dev/timeout | grep 33
    assert_warn $? 0 "scsi_dev/timeout=33"
    #save configuration
    assert_exec 0 "chzdev $ZFCP_LUN --export zfcp-lun.conf"
    #device active off
    assert_exec 0 "chzdev $ZFCP_LUN -d -a -V"
    #device offline and displayed as persistent online and active offline?
    lsluns -a | grep $LUN
    assert_fail $? 1 "ZFCP_LUN $ZFCP_LUN is offline"

    lszdev $ZFCP_LUN --online | grep $ZFCP_LUN
    assert_warn $? 1 "Active configuration offline"

    lszdev $ZFCP_LUN --configured | grep $ZFCP_LUN
    assert_warn $? 0 "Persistent configuration online"
    #apply persistent configuration
    assert_exec 0 "chzdev $ZFCP_LUN --apply"
    #device online and displayed as persistent online and active online?
    lsluns -a | grep $LUN
    assert_fail $? 0 "ZFCP_LUN $ZFCP_LUN is online"

    lszdev $ZFCP_LUN --online | grep $ZFCP_LUN
    assert_warn $? 0 "Active configuration online"

    lszdev $ZFCP_LUN --configured | grep $ZFCP_LUN
    assert_warn $? 0 "Persistent configuration online"
  fi
end_section 1

start_section 1 "10.8 Pre Ipl QETH"

  if grep -q 90_QETH omit; then
    assert_exec 0 "echo 'omitting 90_QETH'"
  else
    #device offline and displayed as persistent offline and active offline?
    lszdev $QETH --online | grep $QETH
    assert_warn $? 1 "Active configuration offline"

    lszdev $QETH --configured | grep $QETH
    assert_warn $? 1 "Persistent configuration offline"

    lsqeth | grep $ENCCW
    assert_fail $? 1 "QETH $QETH is offline"
    #enable device persistent/active
    assert_exec 0 "chzdev qeth $QETH -e -V"
    #device online and displayed as persistent online and active online?
    lsqeth | grep $ENCCW
    assert_fail $? 0 "QETH $QETH is online"

    lszdev $QETH --online | grep $QETH
    assert_warn $? 0 "Active configuration online"

    lszdev $QETH --configured | grep $QETH
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)
    #depends on patch not yet in distro
    assert_exec 0 "chzdev $QETH performance_stats=1"
    lszdev $QETH -i | grep performance_stats | grep 1
    assert_warn $? 0 "performance_stats=1"
    #save configuration
    assert_exec 0 "chzdev $QETH --export qeth.conf"
    #device active off
    assert_exec 0 "chzdev $QETH -y -d -a -V"
    #device offline and displayed as persistent online and active offline?
    lsqeth | grep $ENCCW
    assert_fail $? 1 "QETH $QETH is offline"

    lszdev $QETH --online | grep $QETH
    assert_warn $? 1 "Active configuration offline"

    lszdev $QETH --configured | grep $QETH
    assert_warn $? 0 "Persistent configuration online"
    #apply persistent configuration
    sleep 10
    assert_exec 0 "chzdev $QETH --apply --force"
    #device online and displayed as persistent online and active online?
    lsqeth | grep $ENCCW
    assert_fail $? 0 "QETH $QETH is online"

    lszdev $QETH --online | grep $QETH
    assert_warn $? 0 "Active configuration online"

    lszdev $QETH --configured | grep $QETH
    assert_warn $? 0 "Persistent configuration online"
    #more configuration
    assert_exec 0 "chzdev $QETH buffer_count=32 -p"
    lszdev $QETH -i | grep buffer_count | grep 32
    assert_warn $? 0 "buffer_count=32"
  fi
end_section 1


isVM
if [[ $? -ne 0 ]];then
start_section 1 "10.9 Pre Ipl CTC"
  if grep -q 100_CTC omit; then
    assert_exec 0 "echo 'omitting 100_CTC'"
  else
    #device offline and displayed as persistent offline and active offline?
    lszdev ctc $CTC --online | grep $CTC_IN
    assert_warn $? 1 "Active configuration offline"

    lszdev $CTC --configured | grep $CTC_IN
    assert_warn $? 1 "Persistent configuration offline"

    ifconfig -a | grep $CTC_IN
    assert_fail $? 1 "CTC $CTC is offline"
    #enable device persistent/active

    ctc_ifname=`chzdev ctc $CTC -e -V`
    assert_fail 0 $? "chzdev ctc $CTC -e -V"
    ctc_ifname=`echo "$ctc_ifname" | grep "Network interface:" | awk '{print $3}'`
    echo $ctc_ifname > ctc_ifname

    #device online and displayed as persistent online and active online?
    ifconfig -a | grep $ctc_ifname
    assert_fail $? 0 "CTC $CTC is online"

    lszdev $CTC --online | grep $CTC_IN
    assert_warn $? 0 "Active configuration online"

    lszdev $CTC --configured | grep $CTC_IN
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)

    assert_exec 0 "chzdev $CTC buffer=32769"
    lszdev $CTC -i | grep buffer | grep 32769
    assert_warn $? 0 "buffer=32769"

    #save configuration
    assert_exec 0 "chzdev $CTC --export ctc.conf"
    #device active off
    assert_exec 0 "chzdev $CTC -y -d -a -V"
    #device offline and displayed as persistent online and active offline?
    ifconfig -a | grep $ctc_ifname
    assert_fail $? 1 "CTC $CTC is offline"

    lszdev $CTC --online | grep $CTC_IN
    assert_warn $? 1 "Active configuration offline"

    lszdev $CTC --configured | grep $CTC_IN
    assert_warn $? 0 "Persistent configuration online"


    #apply persistent configuration
    assert_exec 0 "chzdev $CTC --apply"
    #device online and displayed as persistent online and active online?
    ifconfig -a | grep $ctc_ifname
    assert_fail $? 0 "CTC $CTC is online"

    lszdev $CTC --online | grep $CTC_IN
    assert_warn $? 0 "Active configuration online"

    lszdev $CTC --configured | grep $CTC_IN
    assert_warn $? 0 "Persistent configuration online"

    #device active off
    assert_exec 0 "chzdev $CTC -y -d -a"
    #more configuration which only works if device is offline
    assert_exec 0 "chzdev $CTC protocol=1"
    lszdev $CTC -i | grep protocol | grep 1
    assert_warn $? 0 "protocol=1"
  fi
end_section 1
fi

isVM
if [[ $? -ne 0 ]];then
start_section 1 "10.10 Pre Ipl LCS"
  if grep -q 110_LCS omit; then
    assert_exec 0 "echo 'omitting 110_LCS'"
  else
    #device offline and displayed as persistent offline and active offline?
    lszdev lcs $LCS --online | grep $LCS
    assert_warn $? 1 "Active configuration offline"

    lszdev $LCS --configured | grep $LCS
    assert_warn $? 1 "Persistent configuration offline"

    ifconfig -a | grep $LCS_IN
    assert_fail $? 1 "LCS $LCS is offline"
    #enable device persistent/active

    lcs_ifname=`chzdev lcs $LCS -e -V`
    assert_fail 0 $? "chzdev lcs $LCS -e -V"
    lcs_ifname=`echo "$lcs_ifname" | grep "Network interface:" | awk '{print $3}'`
    echo $lcs_ifname > lcs_ifname

    #device online and displayed as persistent online and active online?
    ifconfig -a | grep $lcs_ifname
    assert_fail $? 0 "LCS $LCS is online"

    lszdev $LCS --online | grep $LCS
    assert_warn $? 0 "Active configuration online"

    lszdev $LCS --configured | grep $LCS
    assert_warn $? 0 "Persistent configuration online"
    #change device configuration (#1)

    assert_exec 0 "chzdev $LCS lancmd_timeout=6"
    lszdev $LCS -i | grep lancmd_timeout | grep 6
    assert_warn $? 0 "lancmd_timeout=6"

    #save configuration
    assert_exec 0 "chzdev $LCS --export lcs.conf"
    #device active off
    assert_exec 0 "chzdev $LCS -y -d -a -V"
    #device offline and displayed as persistent online and active offline?
    ifconfig -a | grep $lcs_ifname
    assert_fail $? 1 "LCS $LCS is offline"

    lszdev $LCS --online | grep $LCS
    assert_warn $? 1 "Active configuration offline"

    lszdev $LCS --configured | grep $LCS
    assert_warn $? 0 "Persistent configuration online"
    ifconfig -a
    #wait for device to be taken offline (will fail otherwise)
    sleep 20
    #apply persistent configuration
    assert_exec 0 "chzdev $LCS --apply"
    #device online and displayed as persistent online and active online?
    #explanation?
    ifconfig -a | grep $lcs_ifname
    assert_fail $? 0 "LCS $LCS is online"

    lszdev $LCS --online | grep $LCS
    assert_warn $? 0 "Active configuration online"

    lszdev $LCS --configured | grep $LCS
    assert_warn $? 0 "Persistent configuration online"
  fi
end_section 1
fi
s