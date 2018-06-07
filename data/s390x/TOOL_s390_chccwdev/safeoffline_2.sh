# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

for f in lib/*.sh; do source $f; done

############################################################################################
# This test is to create FBA device which is possible only in zVM environment. Online the
# fba devie and test safe offline the fba device.
############################################################################################
start_section 1 "Safe offline FBA DEVICE"

if isVM; then
	assert_warn $? 0 "The test environment is zVM, continue with test.."

	#Create fba device on zVM Guest
	echo "Create FBA device on zVM Guest"
	_create_fba "$FBA_DEV"

	#Activate fba device on zVM Guest
	echo "Activate fba device $FBA_DEV"
	assert_exec 0 "chccwdev -e $FBA_DEV"

	#List the activated  dasd's on the system after activating fba device
	assert_exec 0 "lsdasd"

	#Execute safe offline the fba device
	echo "safe offline the fba device $FBA_DEV"
	assert_exec 0 "chccwdev -s $FBA_DEV"

	#List all the dasd's after safe offline of fba device
	assert_exec 0 "lsdasd"

	#Detach fba device from zVM Guest
        #### Update ####
        vmcp det "$FBA_DEV"
        #_remove_fba $FBA_DEV
else
	assert_warn 0 0 "The test environment is lpar , not possible to perform this test"
fi

end_section 1

start_section 1 "Safe offline reserved DASD"

#Reserve the lock on the dasd by system 2

echo "DASD $DEV_PAV reservation by system2 $CLIENT_MC"
_reserve_lock "$CLIENT_MC" "$DEV_PAV"

#Safe offline the dasd which is reserved by system2
echo "Safe offline $DEV_PAV reserved by System2 $CLIENT_MC"
echo
echo "When the dasd is reserved by onother system, dasd online fail with (No such device)"

#if [ $(cat /sys/bus/ccw/devices/0.0.$DEV_PAV/online) == "1" ]
#then
#	assert_warn 0 0 "dasd $DEV_PAV already online"
#else
	echo "Activating the dasd $DEV_PAV reserved by system2 $CLIENT_MC"
	assert_exec 1 "chccwdev -e $DEV_PAV"
#fi

#echo "List the dasd's befor performing safe offline"
#assert_exec 0 "lsdasd"

echo "Nothing to safe offline the dasd which already in offline state"
assert_exec 0 "chccwdev -s $DEV_PAV"

echo "List the dasd's before performing safe offline"
assert_exec 0 "lsdasd"

#Release the reserved dasd on system2
echo "Rlease reserve lock on dasd $DEV_PAV on system2 $CLIENT_MC"
_release_lock "$CLIENT_MC" "$DEV_PAV"

echo "Safe offline dasd $DEV_PAV after it is released by System2 $CLIENT_MC"
assert_exec 0 "chccwdev -s $DEV_PAV"

assert_fail $? 0 "Safe offline of released dasd successful"

end_section 1

start_section 1 "Clean-up resources"

if isVM; then
    if [ -n "${DEV_PAV}" ]; then
        assert_exec vmcp det "$DEV_PAV"
        assert_exec vmcp det "$DEV_PALIAS"
    fi
	assert_exec 0 "vmcp det $DEV_HPAV"
	assert_exec 0 "vmcp det $DEV_HPALIAS"
else
	assert_warn 0 0 "Test environment is LPAR. Nothing to detach devices"
fi
end_section 1
end_section 0

show_test_results
