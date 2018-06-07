# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

source lib/auxx.sh || exit 1
source lib/env.sh || exit 1
source lib/dasd.sh || exit 1
source lib/dasd_1.sh || exit 1
source lib/net_setup.sh || exit 1
source lib/net_ifup.sh || exit 1
source lib/net_ping.sh || exit 1
source lib/net_vlan.sh || exit 1
source "./x00_config-file_tool_s390_qethqoat" || exit 1

CLEANUPTESTCASE_PROCEDURE="cleanup"

cleanup(){
	true;
}

setup_testcase(){
	section_start "(INIT) Check preconditions"
	$CLEANUPTESTCASE_PROCEDURE
	assert_warn $? 0 "NULL"
	section_end
}

part_a(){
	section_start "(a) Define 1st Interface with IPV4"
	# START VM-Part (attache):
	isVM
	RET=$?
	if [ "0" = "$RET" ]; then
		echo
		echo "START VM-Part:"
		echo
		net_att_devno_vm "$sE1a $sE1b $sE1c"
		assert_warn $? 0 "DEVNOs attached?"
		echo
	fi

	# START LINUX-Part1 (group):
	echo
	echo "START LINUX-Part1 (group):"
	echo
	net_group_linux $sE1a $sE1b $sE1c $sE1Lay $sE1No $sE1Chp
	assert_warn $? 0 "New interface defined?"
	echo

	# START LINUX-Part2 (ifup):
	echo
	echo "START LINUX-Part2 (ifup):"

	echo "ip"
	net_ifup_linux $sE1a $sE1ip $sE1mask $sE1broad $sE1mac
	assert_warn $? 0 "Setup of new interface done?"

	echo primary_router > /sys/bus/ccwgroup/drivers/qeth/$sE1a/route4
	echo primary_router > /sys/bus/ccwgroup/drivers/qeth/$sE1a/route6
	IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$sE1a/if_name)"
	echo $IFNAME > fileoption

	MODULE="$(lsmod | grep 8021q)"
	if [ -n "$MODULE" ];then
		echo "--->>>>>>>>>> Clean Module <<<<<<<<<<---"
		rmmod 8021q
		assert_warn $? 0 "Remove module"
		lsmod
	fi
	echo
	assert_warn $? 0 "NULL"

	net_vlan_up "VLAN200" "$IFNAME"   "$sE1Vid" "$sE1Vip"     "$sE1Vmask"   "$sE1Vbroad"   "VLAN200"


	section_end
}

part_b(){
	section_start "(b) Define 1st hipersocket Interface with IPV4"

	# START VM-Part (attache):
	isVM
	RET=$?
	if [ "0" = "$RET" ]; then
		echo
		echo "START VM-Part:"
		echo
		net_att_devno_vm "$sE2a $sE2b $sE2c"
		assert_warn $? 0 "DEVNOs attached?"
		echo
	fi

	# START LINUX-Part1 (group):
	echo
	echo "START LINUX-Part1 (group):"
	echo
	net_group_linux $sE2a $sE2b $sE2c $sE2Lay $sE2No $sE2Chp
	assert_warn $? 0 "New interface defined?"
	echo

	# START LINUX-Part2 (ifup):
	sleep 4
	echo
	echo "START LINUX-Part2 (ifup):"

	echo "ip"
	net_ifup_linux $sE2a $sE2ip $sE2mask $sE2broad $sE2mac

	assert_warn $? 0 "Setup of new interface done?"

	IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$sE2a/if_name)"
	echo $IFNAME >> fileoption

	section_end;
}

part_c(){
	section_start "(c) Define 3nd Interface with IPV4+IPV6"

	# START VM-Part (attache):
	isVM
	RET=$?
	if [ "0" = "$RET" ]; then
	echo
	echo "START VM-Part:"
	echo
	net_att_devno_vm "$sE3a $sE3b $sE3c"
	assert_warn $? 0 "DEVNOs attached?"
	echo
	fi

	# START LINUX-Part1 (group):
	echo
	echo "START LINUX-Part1 (group):"
	echo
	net_group_linux $sE3a $sE3b $sE3c $sE3Lay $sE3No $sE3Chp
	assert_warn $? 0 "New interface defined?"
	echo

	# START LINUX-Part2 (ifup):
	sleep 4
	echo
	echo "START LINUX-Part2 (ifup):"
	IFNAME="$(cat /sys/bus/ccwgroup/drivers/qeth/$sE3a/if_name)"

	echo "ip"
	net_ifup_linux $sE3a $sE3ip $sE3mask $sE3broad $sE3mac
	assert_warn $? 0 "Setup of new interface done?"
	ip -6 addr add $sE3ip6 dev $IFNAME
	assert_warn $? 0 "Setup of new interface done?"
	ip addr show dev $IFNAME

	if [ $sE3Lay -eq 0 ]; then
		echo secondary_router > /sys/bus/ccwgroup/drivers/qeth/$sE3a/route4
		echo secondary_router > /sys/bus/ccwgroup/drivers/qeth/$sE3a/route6
	fi
	echo $IFNAME >> fileoption

	section_end
}

################################################################################
# Main
################################################################################
TESTCASES="${TESTCASES:-$x20STEST}"

section_start "START: $0"
init_tests
setup_testcase

echo "Executing the testscript ($0) with the following sections: $TESTCASES"
echo
echo "Run dedicated testcases with TESTCASE = $0"

for i in $TESTCASES; do
   echo
   "part_$i";
   echo
done

show_test_results
