# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

#!/bin/bash

source lib/auxx.sh || exit 1
source lib/env.sh || exit 1

HTC="" # Hyptop command line
HOSTNAME=`hostname`
echo "Hostname is $HOSTNAME"

start_section 0 "hyptop test"

init_tests

calling_hyptop_expected_works ()
{
$HTC
RET=$?
assert_warn 0 $RET "calling $HTC"
[ $RET != 0 ] && exit 1
}

calling_hyptop_expected_fails ()
{
RET=1
$HTC
[ $? != 0 ] && RET=0
assert_warn 0 $RET "calling $HTC"
[ $RET != 0 ] && exit 1
}

main(){
	while [ `mount | grep -c /sys/kernel/debug` -gt 0 ];do
		umount /sys/kernel/debug
		RET=$?
		assert_warn 0 $RET "unmounting debugfs: umount /sys/kernel/debug"
	done

	# now we call hyptop - and check how it fails without debugfs ... as expected -)
	HTC="hyptop"
	calling_hyptop_expected_fails

	# Mounting debugfs (again)
	HTC="mount none -t debugfs /sys/kernel/debug"
	calling_hyptop_expected_works

	# Calling hyptop with correct options
	HTC="hyptop -b -h"
	calling_hyptop_expected_works
	calling_hyptop_expected_works
	HTC="hyptop -b -v"
	calling_hyptop_expected_works
	HTC="hyptop -b -n2" 				# hyptop for the entire CEC
	calling_hyptop_expected_works
        HOSTNAME=`hyptop -b -n1  | sed -ne '4p' | sed -e 's/ .*//'`
	HTC="hyptop -b -n2 -s $HOSTNAME" 		# Calling for current host only
	calling_hyptop_expected_works
	HTC="hyptop -b -n2 -w sys -s $HOSTNAME"	# Calling with detailed window
	calling_hyptop_expected_works
	HTC="hyptop -b -n2 -w sys_list"             	# Calling with window
	calling_hyptop_expected_works
	#HTC="hyptop -n2"				# in screen mode at least once - does not work ...
	#calling_hyptop_expected_works
	# Calling hyptop with incorrect options
	HTC="hyptop -b -n2 -f Y -w sys_list"		# Calling with the wrong letter (-f 'Y')
	calling_hyptop_expected_fails
	HTC="hyptop -b -n2 -s not_there"		# Calling with none existing system name
	calling_hyptop_expected_fails
	HTC="hyptop -b -n1 -Y"				# Wrong option
	calling_hyptop_expected_fails
	HTC="hyptop -n1 -S R"				# Wrong sort key (is different code)
	calling_hyptop_expected_fails

	HTC="hyptop -b -n2 -f c -S c -w sys_list"       # Calling correctly with -S (sort) and -f (field selection)
	calling_hyptop_expected_works
	HTC="hyptop -b -n2 -d 5 -f c -S c -w sys_list"  # with option -d (delay)
	calling_hyptop_expected_works
	HTC="hyptop -b -n2 -f m,c,C,o -w sys_list"      # Calling with -f (field selection)
	calling_hyptop_expected_works
	#fi

	# It's necessary to read and check the output created by this test
	# But we roughly check if it works at all

	if [ `hyptop -b -n1 | wc -l`  -lt 5 ]; then
	        assert_warn 0 1 "Proof hyptop basically works ... counting output lines. Min. is 5"
	        end_section 0
	        exit 1
	else
	        assert_warn 0 0 "Proof hyptop basically works ... counting output lines. Min. is 5"
	fi

	if [ `hyptop -b -n1 -s $HOSTNAME | grep -c -i $HOSTNAME` -lt 1 ]; then
		assert_warn 0 1 "Proof that it basically works ... is the local host listed?"
	        end_section 0
		exit 1
	else
		assert_warn 0 0 "Proof that it basically works ... is the local host listed?"
	fi

	# Display the Summary
	show_test_results


}

# for debugging, uncomment the following line to get log output on the target guest VM
#main 2>&1 | tee hyptop.log
main
