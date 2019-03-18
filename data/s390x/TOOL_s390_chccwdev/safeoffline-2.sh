# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# set -x

for f in lib/*.sh; do source $f; done

verifySafeOfflineDataIntegrity() {
    rm -rf /tmp/strings.txt

    echo "IBM
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    GANESH - Testing, testing, 1 2 3
    MANU " >> /tmp/strings.txt

    echo " TEST 9 ===>  Perform safeoffline with the LDL device and verify its contents"

    if [ -z "${DEV_PAV}" ]; then
        echo "Skipping test (Value DEV_PAV='${DEV_PAV}')";
    else
        assert_exec 0 "chccwdev -e $DEV_PAV"
        assert_exec 0 "chccwdev -e $DEV_PALIAS"
        # expected 0
        sleep 5

        lsdasd | grep $DEV_PAV
        assert_fail $? 0 "Verfing if an PAV DASD is setup; if failed look if PAV dasd is specified correctly"

        dev_node="/dev/`lsdasd | grep $DEV_PAV | awk ' { print $3 } '`"
        echo $dev_node

        if dasdfmt --help | grep -q -- "-f "; then
            assert_exec 0 "dasdfmt -f $dev_node -b 4096 -y -d ldl"
        else
            assert_exec 0 "dasdfmt -b 4096 -y -d ldl $dev_node"
        fi
        # expected 0
        sleep 5

        assert_exec 0 "dd if=/tmp/strings.txt of=$dev_node"
        #expected 0 - fill the disk with data.

        sleep 5

        assert_exec 0 "chccwdev -s $DEV_PAV"
        assert_exec 0 "chccwdev -s $DEV_PALIAS"
        # expected 0
        sleep 5

        assert_exec 0 "chccwdev -e $DEV_PAV"
        assert_exec 0 "chccwdev -e $DEV_PALIAS"
        # expected 0

        sleep 5
        dev_node="/dev/`lsdasd | grep $DEV_PAV | awk ' { print $3 } '`"
        echo $dev_node

        assert_exec 0 "dd if=$dev_node count=2 | hexdump -C | grep IBM"
        #expected 0 - search the begin of the text for data validity
        sleep 3

        assert_exec 0 "dd if=$dev_node count=2 | hexdump -C | grep MANU"
        #expected 0 - search the end of the text for data validity

        sleep 5
        assert_exec 0 "chccwdev -d $DEV_PAV"
        assert_exec 0 "chccwdev -d $DEV_PALIAS"
        # expected 0

        sleep 5
    fi

    echo " TEST 10 ===>  Perform safeoffline with the CDL device and verify its contents"

    if [ -z "${DEV_PAV}" ]; then
        echo "Skipping test (Value DEV_PAV='${DEV_PAV}')";
    else
        assert_exec 0 "chccwdev -e $DEV_PAV"
        assert_exec 0 "chccwdev -e $DEV_PALIAS"
        # expected 0
        sleep 5

        lsdasd | grep $DEV_PAV
        assert_fail $? 0 "Verfing if an PAV DASD is setup; if failed look if PAV dasd is specified correctly"

        sleep 1
        dev_node="/dev/`lsdasd | grep $DEV_PAV | awk ' { print $3 } '`"
        echo $dev_node

        if dasdfmt --help | grep -q -- "-f "; then
            assert_exec 0 "dasdfmt -f $dev_node -b 4096 -y -d cdl"
        else
            assert_exec 0 "dasdfmt -b 4096 -y -d cdl $dev_node"
        fi
        # expected 0
        sleep 5

        assert_exec 0 "dd if=/tmp/strings.txt of=$dev_node seek=192"
        #expected 0 - fill the disk with data.

        sleep 1

        assert_exec 0 "chccwdev -s $DEV_PAV"
        assert_exec 0 "chccwdev -s $DEV_PALIAS"
        # expected 0
        sleep 5

        assert_exec 0 "chccwdev -e $DEV_PAV"
        assert_exec 0 "chccwdev -e $DEV_PALIAS"
        # expected 0
        sleep 5

        dev_node="/dev/`lsdasd | grep $DEV_PAV | awk ' { print $3 } '`"
        echo $dev_node
        sleep 1

        assert_exec 0 "dd if=$dev_node count=193 | hexdump -C | grep IBM"
        #expected 0 - search the begin of the text for data validity
        sleep 5

        assert_exec 0 "dd if=$dev_node count=193 | hexdump -C | grep MANU"
        #expected 0 - search the end of the text for data validity

        sleep 1
        assert_exec 0 "chccwdev -d $DEV_PAV"
        assert_exec 0 "chccwdev -d $DEV_PALIAS"
        # expected 0

        sleep 5
    fi
}

verifySafeOfflineWithSysfsFailFast() {
    echo " TEST 11 ===>  Perform safeoffline with few sysfs attrib set"

    assert_exec 0 "chccwdev -d $DEVICE"
    # expected 0

    #take a backup of original data
    org_failfast=`cat /sys/bus/ccw/devices/0.0.$DEVICE/failfast`
    org_erplog=`cat /sys/bus/ccw/devices/0.0.$DEVICE/erplog`
    org_eer_enabled=`cat /sys/bus/ccw/devices/0.0.$DEVICE/eer_enabled`

    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/failfast"
    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/erplog"
    sleep 5

    assert_exec 0 "chccwdev -e $DEVICE"
    # expected 0
    sleep 5

    assert_exec 0 "echo 1 > /sys/bus/ccw/devices/0.0.$DEVICE/eer_enabled"
    assert_exec 0 "echo 45 > /sys/bus/ccw/devices/0.0.$DEVICE/expires"

    lsdasd | grep $DEVICE
    assert_fail $? 0 "Verfing if an ECKD DASD is setup; if failed look if ECKD dasd is specified correctly"
    sleep 5

    dev_node="/dev/`lsdasd | grep $DEVICE | awk ' { print $3 } '`"
    echo $dev_node

    if dasdfmt --help | grep -q -- "-f "; then
        assert_exec 0 "dasdfmt -f $dev_node -b 4096 -y -d ldl"
    else
        assert_exec 0 "dasdfmt -b 4096 -y -d ldl $dev_node"
    fi
    # expected 0

    sleep 5
    assert_exec 0 "dd if=/tmp/strings.txt of=$dev_node"
    #expected 0 - fill the disk with data.

    sleep 2

    assert_exec 0 "chccwdev -s $DEVICE"
    # expected 0
    sleep 2

    assert_exec 0 "chccwdev -e $DEVICE"
    # expected 0
    sleep 5

    dev_node="/dev/`lsdasd | grep $DEVICE | awk ' { print $3 } '`"
    echo $dev_node

    assert_exec 0 "dd if=$dev_node count=2 | hexdump -C | grep IBM"
    #expected 0 - search the begin of the text for data validity
    sleep 2

    assert_exec 0 "dd if=$dev_node count=2 | hexdump -C | grep MANU"
    #expected 0 - search the end of the text for data validity
    sleep 2

    assert_exec 0 "echo $org_eer_enabled > /sys/bus/ccw/devices/0.0.$DEVICE/eer_enabled"

    sleep 2
    assert_exec 0 "chccwdev -d $DEVICE"
    # expected 0

    assert_exec 0 "echo $org_failfast > /sys/bus/ccw/devices/0.0.$DEVICE/failfast"
    assert_exec 0 "echo $org_erplog > /sys/bus/ccw/devices/0.0.$DEVICE/erplog"


    echo "Resetting the DASD to CDL format i.e default"

    assert_exec 0 "chccwdev -e $DEVICE"
    # expected 0
    sleep 5

    dev_node="/dev/`lsdasd | grep $DEVICE | awk ' { print $3 } '`"
    echo $dev_node


    if dasdfmt --help | grep -q -- "-f "; then
        assert_exec 0 "dasdfmt -f $dev_node -b 4096 -y -d cdl"
    else
        assert_exec 0 "dasdfmt -b 4096 -y -d cdl $dev_node"
    fi
    # expected 0
    sleep 5

    assert_exec 0 "chccwdev -d $DEVICE"
    # expected 0
    sleep 5

    if [ -n "${DEV_PAV}" ]; then
        assert_exec 0 "chccwdev -e $DEV_PAV"
        # expected 0
        sleep 5

        dev_node="/dev/`lsdasd | grep $DEV_PAV | awk ' { print $3 } '`"
        echo $dev_node

        if dasdfmt --help | grep -q -- "-f "; then
            assert_exec 0 "dasdfmt -f $dev_node -b 4096 -y -d cdl"
        else
            assert_exec 0 "dasdfmt -b 4096 -y -d cdl $dev_node"
        fi
        # expected 0
        sleep 5

        assert_exec 0 "chccwdev -d $DEV_PAV"
        # expected 0
        sleep 5
    fi

    rm -rf /tmp/strings.txt
}

cleanup() {
    if isVM ; then
        vmcp det $DEVICE
        if [ -n "${DEV_PAV}" ]; then
            vmcp det $DEV_PAV
            vmcp det $DEV_PALIAS
        fi
        vmcp det $DEV_HPALIAS
        vmcp det $DEV_HPAV
        vmcp det $SCSI
    fi
}
