# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

REGEX_KERNEL_PROBLEMS="(badness|kernel bug|corruption|erp failed|dereference|oops|stack overflow|backtrace|cpu capability change)"

init_tests(){
   TESTCASE_SECTION_COUNTER=0;
   TESTCASE_NUMBER_OF_FAILED=0
   TESTCASE_NUMBER_OF_PASS=0
}


show_test_results(){
 echo
 echo "===> Results:"
 echo
 echo "Failed tests     : $TESTCASE_NUMBER_OF_FAILED"
 echo "Successful tests : $TESTCASE_NUMBER_OF_PASS"
 echo
 if [ $TESTCASE_NUMBER_OF_FAILED -ne 0 ]; then return 1; fi;
}

assert_exec(){
   local EXPECTEDRET="$1";
   local STARTTIME="$SECONDS"
   shift;
   echo "[EXECUTING] : '$@'"
   eval "$@"
   local RET="$?"
   assert_warn $RET $EXPECTEDRET "command execution with $(($SECONDS - $STARTTIME)) seconds runtime"
   return $?
}

assert_warn () {
	local i;
	local PASSED="[PASSED]";
	local FAILED="[FAILED]";
	local EXITCODE="$1";
	local MESSAGE="${!#}";
	local ASSERTCODES_COUNT=$(($#-2));
	local ASSERTCODES="${@:2:$ASSERTCODES_COUNT}";
	local FOUND=false;

	for (( i = 2; i < $#; i++ )); do
		if [ "$EXITCODE" == "${!i}" ]; then
			FOUND=true;
			break;
		fi
	done

	if $FOUND; then
		echo -e "$PASSED :: $MESSAGE :: $EXITCODE";
		TESTCASE_NUMBER_OF_PASS="$(($TESTCASE_NUMBER_OF_PASS + 1 ))";
		return 0;
	fi
	echo -e "$FAILED :: $MESSAGE :: $EXITCODE (expected ${ASSERTCODES// /, })";
	TESTCASE_NUMBER_OF_FAILED="$(($TESTCASE_NUMBER_OF_FAILED + 1 ))";
	return 1
}

assert_fail(){
	local i;
	local PASSED="[PASSED]";
	local FAILED="[FAILED]";
	local EXITCODE="$1";
	local MESSAGE="${!#}";
	local ASSERTCODES_COUNT=$(($#-2));
	local ASSERTCODES="${@:2:$ASSERTCODES_COUNT}";
	local FOUND=false;

	for (( i = 2; i < $#; i++ )); do
		if [ "$EXITCODE" == "${!i}" ]; then
			FOUND=true;
			break;
		fi
	done

	if $FOUND; then
		echo -e "$PASSED :: $MESSAGE :: $EXITCODE";
		TESTCASE_NUMBER_OF_PASS="$(($TESTCASE_NUMBER_OF_PASS + 1 ))";
		return 0;
	fi
	echo -e "$FAILED :: $MESSAGE :: $EXITCODE (expected ${ASSERTCODES// /, })";
	echo -e "\nATTENTION: THIS CAUSES A DIRECT STOP OF THE TESTCASE";
	TESTCASE_NUMBER_OF_FAILED="$(($TESTCASE_NUMBER_OF_FAILED + 1 ))";
	[ "$(type -t show_test_results)" == "function" ] && show_test_results;
	echo "** END OF TESTCASE";
	exit 1;
}

start_section(){
   echo -e "\n#####################################################################################"
   echo -e "### [$1] START SECTION : $2"
   echo -e "###"
   echo -e "### TIMESTAMP: $(date --date="today" "+%Y-%m-%d %H:%M:%S")\n"
   dmesg -c | egrep -C1000 -i "$REGEX_KERNEL_PROBLEMS" && assert_warn 1 0 "Kernel messages"
   return 0
}

end_section(){
   dmesg -c | egrep -C1000 -i "$REGEX_KERNEL_PROBLEMS" && assert_warn 1 0 "Kernel messages"
   echo -e "\n### TIMESTAMP: $(date --date="today" "+%Y-%m-%d %H:%M:%S")"
   echo -e "###"
   echo -e "### [$1] END SECTION";
   echo -e "#####################################################################################\n"
   return 0
}

section_start () {
    start_section "$TESTCASE_SECTION_COUNTER" "$1"
    section_up;
}
section_end () {
    section_down;
    end_section "$TESTCASE_SECTION_COUNTER"
}
section_up () {
  TESTCASE_SECTION_COUNTER=$(( TESTCASE_SECTION_COUNTER + 1 ));
  return $TESTCASE_SECTION_COUNTER;
}
section_down () {
  test "$TESTCASE_SECTION_COUNTER" -gt "0" && TESTCASE_SECTION_COUNTER=$(( TESTCASE_SECTION_COUNTER - 1 ));
  return $TESTCASE_SECTION_COUNTER;
}
