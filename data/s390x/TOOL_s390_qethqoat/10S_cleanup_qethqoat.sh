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
	rm -f fileoption
	assert_warn $? 0 "NULL"
	section_end
}

part_a(){
	section_start "(a) Delete all Interface except LAN eth0"
	# - - - - - - - - - - - - - - - - - - - - -
	# Delete all LINUX interfaces:
	# - - - - - - - - - - - - - - - - - - - - -
	net_cleanup_linux "$sLANa"
	assert_warn $? 0 "net_cleanup_linux NULL"

	section_end
}

part_b(){
	section_start "(b) Detach all DEVNOs except 0.0.F5xx"

	# - - - - - - - - - - - - - - - - - - - - -
	# Detach all DEVNOs except 0.0.F5xx
	# - - - - - - - - - - - - - - - - - - - - -
	if ! isVM; then
	   echo "Not a VM-guest!"
	   return
	else
	   echo "Yes a VM-guest!"
	   net_cleanup_vm "$sLANa $sLANb $sLANc"
	fi
	vmcp 'q v osa'
	assert_warn $? 0 "vmcp 'q v osa' -- NULL"

	section_end
}

################################################################################
# MAIN
################################################################################
TESTCASES="${TESTCASES:-$x10STEST}"

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
