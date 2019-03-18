# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

# Test case Description: the main goal of this test is to verify the
# basic functionality of chchp and lschp tools. In order to do so,
# initially basic options of both commands are tested (help menu and
# tool version). Then, using chchp, a channel path given as parameter
# is disabled, enabled, deconfigured and configured. lschp is used to
# check if the channel path current state is the expected one.
# This script if the basic options of chchp are working properly and
# disables, enables, deconfigures and configures a channel path using
# chchp. Then verifies the result with lschp.

source "lib/auxx.sh" || exit 1
source "lib/env.sh" || exit 1

chp::getVary() {
	CHP="$1";
	CSS="0";
	test -z "${CHP}" && return 1;
	if [[ "${CHP}" =~ [:digit:]*\.[:digit:]* ]]; then
		CSS="${CHP%.*}";
		CSS="${CSS:=0}";
		CHP="${CHP#*.}";
	fi

	if [ "$(cat "/sys/devices/css${CSS}/chp${CSS}.${CHP}/status")" == "online" ]; then
		echo 1;
	elif [ "$(cat "/sys/devices/css${CSS}/chp${CSS}.${CHP}/status")" == "offline" ]; then
		echo 0;
	else
		return 1;
	fi
	return 0;
}

chp::getConfigure() {
	CHP="$1";
	CSS="0";
	test -z "${CHP}" && return 1;
	if [[ "${CHP}" =~ [:digit:]*\.[:digit:]* ]]; then
		CSS="${CHP%.*}";
		CSS="${CSS:=0}";
		CHP="${CHP#*.}";
	fi

	cat "/sys/devices/css${CSS}/chp${CSS}.${CHP}/configure";
	return 0;
}

verifyBasicOptions() {
	assert_exec 0 "chchp --help"
	assert_exec 0 "chchp -h"
	assert_exec 0 "chchp --version"

	if chchp --help | grep -q "[[:space:]]*-V,"; then
		echo "Found -V in --help information";
		assert_exec 0 "chchp -V";
	else
		echo "Not found -V in --help information - skipping test";
	fi

	echo "Verify that -v is still vary and not version";
	chchp -v 2>&1 | grep -Eq "(Option '-v' requires an argument|chchp: --vary requires an argument)";
	[[ "${PIPESTATUS[0]}" == 1 && "${PIPESTATUS[1]}" == 0 ]];
	assert_warn $? 0 "Verify 'chchp -v' still requires an argument";
}

verifyVaryAndConfigure() {
	# Use --vary and -v
	echo "Turn off CHPID $chpid_1 using Vary"
	assert_exec 0 "chchp --vary 0 $chpid_1"
	if [[ "$(chp::getVary "${chpid_1}")" -eq 0 ]]; then
		echo "CHPID $chpid_1 vary OFF was successful"
	else
		echo "CHPID vary OFF failed"
	fi

	sleep 5

	echo;
	echo "Turn on CHPID $chpid_1 using Vary"
	assert_exec 0 "chchp -v 1 $chpid_1"
	if [[ "$(chp::getVary "${chpid_1}")" -eq 1 ]]; then
		echo "CHPID $chpid_1 vary ON was successful"
	else
		echo "CHPID vary ON failed"
	fi

	sleep 5

	# Use --configure and -c
	if ! isVM; then
		echo "Turn off CHPID $chpid_1 using configure"
		assert_exec 0 "chchp --configure 0 $chpid_1"
		if [[ "$(chp::getConfigure "${chpid_1}")" -eq 0 ]]; then
			echo "CHPID $chpid_1 configure OFF was successful"
		else
			echo "CHPID configure OFF failed"
		fi

		sleep 5

		echo;
		echo "Turn ON CHPID $chpid_1 using configure"
		assert_exec 0 "chchp -c 1 $chpid_1"
		if [[ "$(chp::getConfigure "${chpid_1}")" -eq 1 ]]; then
			echo "CHPID $chpid_1 configure ON was successful"
		else
			echo "CHPID configure ON failed"
		fi
	fi

	sleep 5

	# Use attribute status
	echo;
	echo "Turn OFF CHPID $chpid_1 using status attribute"
	assert_exec 0 "chchp -a status=0 $chpid_1"
	if [[ "$(chp::getVary "${chpid_1}")" -eq 0 ]]; then
		echo "CHPID $chpid_1 vary OFF using attribute 'status' was successful"
	else
		echo "CHPID vary OFF failed"
	fi

	sleep 5

	echo;
	echo "Turn ON CHPID $chpid_1 using status attribute"
	assert_exec 0 "chchp -a status=1 $chpid_1"
	if [[ "$(chp::getVary "${chpid_1}")" -eq 1 ]]; then
		echo "CHPID $chpid_1 vary ON using attribute 'status' was successful"
	else
		echo "CHPID vary ON using attribute failed"
	fi

	sleep 5

	# Use attribute configure
	if ! isVM; then
		echo;
		echo "Turn OFF CHPID $chpid_1 using configure attribute"
		assert_exec 0 "chchp -a configure=0 $chpid_1"
		if [[ "$(chp::getConfigure "${chpid_1}")" -eq 0 ]]; then
			echo "CHPID $chpid_1 configure OFF using attribute 'configure' was successful"
		else
			echo "CHPID configure attribute OFF failed"
		fi

		sleep 5

		echo;
		echo "Turn ON CHPID $chpid_1 using configure"
		assert_exec 0 "chchp -a configure=1 $chpid_1"
		if [[ "$(chp::getConfigure "${chpid_1}")" -eq 1 ]]; then
			echo "CHPID $chpid_1 configure ON using attribute 'configure' was successful"
		else
			echo "CHPID configure attribute ON failed"
		fi
	fi
}

################################################################################
# Start
################################################################################

main(){

	init_tests
	section_start "Perform test on chchp tool "

	chpid_1="$1"
	test -z "$chpid_1" \
		&& assert_fail 0 1 "No test CHPID given as parameter";

	section_start "Verify basic options";
	verifyBasicOptions;
	section_end;

	section_start "Verify vary/configure of CHPID '$chpid_1' with chchp";
	verifyVaryAndConfigure;
	section_end

	show_test_results

}

# for debugging, uncomment the following line to get log output on the target guest VM
#main $1 2>&1 | tee chchpmain.log
main $1
