# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
#set -x
###############################################################################
# How to run?  -  ./vmcp_main.sh
###############################################################################


source lib/auxx.sh || exit 1
source lib/env.sh || exit 1

verifyBasicVMCPCommands() {
	assert_exec 0 "vmcp --version";
	assert_exec 0 "vmcp --help";
	assert_exec 0 "vmcp -v";
	assert_exec 0 "vmcp -h";
	assert_exec 0 "vmcp q dasd";
}

verifyErrorConditions() {
	assert_exec 4 "vmcp -L"
	assert_exec 4 "vmcp -m q dasd"
	assert_exec 1 "vmcp dasddasddasd"
}

################################################################################
# Start
################################################################################

init_tests;

section_start " TOOL vmcp : Perform test on vmcp";

isVM || assert_fail $? 0 "TOOL vmcp : Not supported on LPAR";

section_start "Verify basic vmcp commands";
verifyBasicVMCPCommands;
section_end;

section_start "Verify vmcp error conditions";
verifyErrorConditions;
section_end;

show_test_results;
