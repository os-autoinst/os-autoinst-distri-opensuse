# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# set -x

for f in lib/*.sh; do source $f; done

initDeviceSetup() {
    if isVM; then
        modprobe vmcp
        vmcp att "$DEVICE" '*'
        if [ -n "${DEV_PAV}" ]; then
            vmcp att "$DEV_PAV" '*'
            vmcp att "$DEV_PALIAS" '*'
        fi
        vmcp att "$DEV_HPAV" '*'
        vmcp att "$DEV_HPALIAS" '*'
        vmcp att "$SCSI" '*'
        sleep 3
    fi
}

verifySafeOfflineSupport() {
    echo " TEST 1 ===> Checking whether the safeoffline support is present"
    [ -e "/sys/bus/ccw/devices/0.0.$DEVICE/safe_offline" ];
    assert_fail $? 0 "safeoffline attribute is not present in the sysfs!! Retry with the latest Driver version"
    chccwdev -h | grep safeoffline
    assert_fail $? 0 "safeoffline option is not present in the chccwdev tool. !! Retry with the latest s390tools"

    echo " TEST 2 ===> Verifing the man pages"
    assert_exec 0 "man chccwdev | grep safeoffline"

    echo " TEST 3 ===> Verify the safeoffline for ECKD devices"
    assert_exec 0 "chccwdev -e $DEVICE"
    sleep 5
    lsdasd | grep $DEVICE
    assert_fail $? 0 "Set DASD('$DEVICE') online"
    assert_exec 0 "chccwdev -s $DEVICE"

    sleep 3
}

verifySafeOfflinePAVAndAliasDevices () {
    echo " TEST 4 ===> Verify the safeoffline for PAV and aliases devices"
    if [ -z "${DEV_PAV}" ]; then
        echo "Skipping test (Value DEV_PAV='${DEV_PAV}')";
    else
        assert_exec 0 "chccwdev -e $DEV_PAV"
        ######## Update ########
        chccwdev -d "$DEV_PAV"
        sleep 10
        chccwdev -e "$DEV_PAV"
        sleep 15
        #######################
        assert_exec 0 "chccwdev -e $DEV_PALIAS"
        sleep 15
        lsdasd | grep "$DEV_PAV"
        assert_fail $? 0 "PAV devices cannot be set online"
        assert_exec 0 "chccwdev -s $DEV_PAV"
        assert_exec 0 "chccwdev -s $DEV_PALIAS"

        sleep 5
    fi
}

verifySafeOfflineHyperPAVAndAliasDevices() {
    echo " TEST 5 ===> Verify the safeoffline for Hyper PAV and aliases devices"
    assert_exec 0 "chccwdev -e $DEV_HPAV"
    assert_exec 0 "chccwdev -e $DEV_HPALIAS"
    sleep 5
    lsdasd | grep "$DEV_HPAV"
    assert_fail $? 0 "Hyper PAV devices cannot be set online"
    assert_exec 0 "chccwdev -s $DEV_HPAV"
    assert_exec 0 "chccwdev -s $DEV_HPALIAS"

    sleep 4
}

verifyErrorConditions() {
    echo " TEST 6 ===> Perform negative tests"

    assert_exec 0 "chccwdev -e $DEVICE"
    sleep 5
    assert_exec 0 "chccwdev -s $DEVICE"
    sleep 3
    assert_exec 1 "chccwdev -s $DEVICE | grep already"
    # expected 1   - Trying to safeoffline a device which is already offlined.

    sleep 3

    assert_exec 0 "chccwdev -e $DEVICE"
    # expected 0
    sleep 5
    assert_exec 1 "chccwdev -es $DEVICE "
    # expected 1   - Invalid options.

    assert_exec 0 "chccwdev -e $DEVICE"
    # expected 0
    sleep 5
    assert_exec 0 "chccwdev -s -d $DEVICE"
    # expected 0   - if -s and -d is both used. -s gets higher priority.
    sleep 2


    assert_exec 0 "chccwdev -e $DEVICE"
    # expected 0
    sleep 5
    assert_exec 1 "chccwdev -s -e $DEVICE "
    # expected 1   - Invalid options.

    sleep 2
    assert_exec 0 "chccwdev -e $DEVICE"
    # expected 0
    sleep 5
    assert_exec 0 "chccwdev -s -s $DEVICE"
    # expected 0
    sleep 2

    assert_exec 1 "chccwdev -e $DEVICE -s $DEVICE"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev -s"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev -s 94"
    # expected 1   - Invalid options.

    sleep 2

    assert_exec 1 "chccwdev -s -9401"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev -s 0.094"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev -s0.09401"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev -s $DEVICE -d $DEVICE -e $DEVICE"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev -s -s -s"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev -s $DEVICE,"
    # expected 1   - Invalid options.

    sleep 2

    if [ -n "${DEV_PAV}" ]; then
        assert_exec 0 "chccwdev -e $DEVICE,$DEV_PAV,$DEV_HPAV"
        sleep 5
        assert_exec 0 "chccwdev -e $DEV_PALIAS"
        # expected 0
    else
        assert_exec 0 "chccwdev -e $DEVICE,$DEV_HPAV"
    fi
    sleep 2
    assert_exec 0 "chccwdev -e $DEV_HPALIAS"
    # expected 0
    sleep 5
    if [ -n "${DEV_PAV}" ]; then
        assert_exec 0 "chccwdev -s $DEVICE,$DEV_PAV,$DEV_HPAV"
        sleep 5
        assert_exec 0 "chccwdev -s $DEV_PALIAS"
    else
        assert_exec 0 "chccwdev -s $DEVICE,$DEV_HPAV"
    fi
    # expected 0
    sleep 2
    assert_exec 0 "chccwdev -s $DEV_HPALIAS"
    # expected 0
    sleep 5

    assert_exec 1 "chccwdev --safeoffli $DEVICE"
    # expected 1   - Invalid options.

    if [ -n "${DEV_PAV}" ]; then
        assert_exec 0 "chccwdev -e $DEVICE,$DEV_PAV,$DEV_HPAV"
        sleep 2
        assert_exec 0 "chccwdev -e $DEV_PALIAS"
    else
        assert_exec 0 "chccwdev -e $DEVICE,$DEV_HPAV"
    fi
    sleep 2
    assert_exec 0 "chccwdev -e $DEV_HPALIAS"
    # expected 0
    sleep 5
    if [ -n "${DEV_PAV}" ]; then
        assert_exec 0 "chccwdev --safeoffline $DEVICE $DEV_PAV $DEV_HPAV"
        sleep 5
        assert_exec 0 "chccwdev --safeoffline $DEV_PALIAS"
    else
        assert_exec 0 "chccwdev --safeoffline $DEVICE $DEV_HPAV"
    fi
    sleep 5
    assert_exec 0 "chccwdev --safeoffline $DEV_HPALIAS"
    # expected 0
    sleep 5

    assert_exec 1 "chccwdev --safeoffline"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev --safeoffline -90"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev --safeoffline -e"
    # expected 1   - Invalid options.

    sleep 3
    assert_exec 1 "chccwdev --safeoffline -e $DEVICE"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev --safeoffline --online $DEVICE"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev --safeoffline $DEVICE --online $DEVICE"
    # expected 1   - Invalid options.

    if [ -n "${DEV_PAV}" ]; then
        assert_exec 0 "chccwdev --safeoffline $DEVICE -d $DEV_PAV"
        # expected 0   - Invalid options.
    fi

    assert_exec 1 "chccwdev --safeoffline 0.0.9452242141421412421421424243214124214321421342134214321421421421"
    # expected 1   - Invalid options.

    assert_exec 1 "chccwdev --s"
    # expected 1   - Invalid options.

    sleep 3
}

verifySafeOfflineWithSysfs() {
    echo " TEST 7 ===> safeoffline with the sysfs Attribs"

    assert_exec 0 "chccwdev -e $DEVICE"
    sleep 5
    assert_exec 0 "chccwdev -s $DEVICE"
    assert_exec 1 "echo 0 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    assert_exec 1 "echo > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    assert_exec 1 "echo 35 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    assert_exec 1 "echo -35 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    assert_exec 1 "echo 23424242431421414124124214 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    sleep 5
    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/online"
    sleep 5
    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    sleep 3
    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/online"
    sleep 5
    assert_exec 0 "echo woirtwoiuoewutoewutroweuitoewiutweutowe32421421412124fwjhbchjwcbjcsjbcjsbc > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    sleep 3
    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/online"
    sleep 5
    assert_exec 0 "echo 9589 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    sleep 3
    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/online"
    sleep 5
    assert_exec 0 "echo -3524328742 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
    sleep 3
    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/online"
    sleep 5
    assert_exec 0 "echo 23424242431421414124124214 > /sys/bus/ccw/devices/0.0.$DEVICE/safe_offline"
}

verifySafeOfflineWithNonDASD() {
    echo " TEST 8 ===> safeoffline with the non DASD device may be SCSI drive"

    assert_exec 0 "chccwdev -e $SCSI"
    # expected 0

    sleep 5
    assert_exec 1 "chccwdev -s $SCSI"
    # expected 1   - safeoffline non DASD device.

    sleep 2
}
