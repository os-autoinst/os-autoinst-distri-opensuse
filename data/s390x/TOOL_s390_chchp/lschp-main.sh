# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

###############################################################################
# How to run?  -  ./lschp-main.sh
###############################################################################

# Test case Description: the main goal of this test is to verify the
# basic functionality of chchp and lschp tools. In order to do so,
# initially basic options of both commands are tested (help menu and
# tool version). Then, using chchp, a channel path given as parameter
# is disabled, enabled, deconfigured and configured. lschp is used to
# check if the channel path current state is the expected one.
# This script verifies if s390 package is installed and if the basic
# options of lschp are working properly.

source "lib/env.sh" || exit 1
source "lib/auxx.sh" || exit 1



#---

verifyBasicOptions() {
	assert_exec 0 "lschp --version";
	assert_exec 0 "lschp --help";
	assert_exec 0 "lschp -v";
	assert_exec 0 "lschp -h";
	assert_exec 0 "lschp";
}

verifyErrorConditions() {
	local option;
	echo "Verify that other options are invalid";
	for option in '-x' '--long-x' 'asdf' '1234'; do
		echo "Executing: lschp ${option}";
		lschp ${option} 2>&1 | grep -E -- "Invalid (argument|option) '{0,1}${option}'{0,1}";
		[[ "${PIPESTATUS[0]}" == 1 && "${PIPESTATUS[1]}" == 0 ]];
		assert_warn $? 0 "Verify error condition with option: '${option}'";
	done;
}

################################################################################
# Start
################################################################################
main(){
	init_tests
	section_start "TOOL lschp : Perform test on lschp"


	section_start "Verify basic lschp options";
	verifyBasicOptions;
	section_end;


	section_start "Verify lschp error conditions";
	verifyErrorConditions;
	section_end;


	show_test_results

}

# for debugging, uncomment the following line to get log output on the target guest VM
# main 2>&1 | tee lschp-main.log
main
