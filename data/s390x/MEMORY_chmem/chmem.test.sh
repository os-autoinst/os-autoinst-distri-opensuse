# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
RUNTIME=$1                # Runtime in minutes
START_TIME=`date '+%s'`   # Now in secs since 1970
CONF_BLOCKS_OFFLINE_MB=0
CONF_BLOCKS_ONLINE_MB=0
NON_CONF_BLOCKS_TOT_MB=0
ALL_CONF_MB_INIT=0
ALL_CONF_MB=0
NO_CONF_MEM_COUNT=0

[ -z $RUNTIME ] && RUNTIME=120

for f in lib/*.sh; do source $f; done

start_section 0 "chmem test initialization"

init_tests

# Checking for non configurable memory in total
NON_CONF_BLOCKS_TOT_MB=`lsmem -a |grep "no" | awk '{print $2}' | awk '{s+=$1}END{print s}'`

CONF_BLOCKS_ONLINE_MB=`lsmem -a | grep yes | awk '{print $2}' | awk '{s+=$1}END{print s}'`

CONF_BLOCKS_OFFLINE_MB=`lsmem -a | grep "offline.*-" | awk '{print $2}' | awk '{s+=$1}END{print s}'`

[ -z $CONF_BLOCKS_ONLINE_MB ] && CONF_BLOCKS_ONLINE_MB=0
[ -z $CONF_BLOCKS_OFFLINE_MB ] && CONF_BLOCKS_OFFLINE_MB=0

ALL_CONF_MB_INIT=`expr $CONF_BLOCKS_ONLINE_MB + $CONF_BLOCKS_OFFLINE_MB`

echo "Initial non-configurable main storage:  " $NON_CONF_BLOCKS_TOT_MB "MB"
echo "Initial configurable memory but offline:" $CONF_BLOCKS_OFFLINE_MB "MB"
echo "Initial configurable memory and online: " $CONF_BLOCKS_ONLINE_MB  "MB"
echo "Inital configurable memory in total:    " $ALL_CONF_MB_INIT       "MB"

# Find the blocks which are configurable and online
# IMPORTANT: exclude first block if it's marked as configurable, since it will always be used by kernel.
CONF_BLOCKS_ONLINE=`lsmem -a | grep yes | egrep -v "0x[0]{16}-" | awk '{print $1}'`

# The blocks which are configurable but offline
CONF_BLOCKS_OFFLINE=`lsmem -a | grep "offline.*-" | awk '{print $1}'`

# All blocks which can be configured
CONF_BLOCKS=`echo $CONF_BLOCKS_ONLINE " " $CONF_BLOCKS_OFFLINE`
COUNT=`echo $CONF_BLOCKS | wc -w` # No. of blocks which can be configured

# The two options of chmem -d and -e - we will randomize them later
ACTIONS="e d"

# Check if removable memory is available at all if not good bye
[ $COUNT != 0 -a $COUNT != "" ]
ret=$?
assert_warn $ret 0 "At least one configurable memory block available"
[ $ret != 0 ] && end_section 0 && exit 1

# Check if setting memory online worked
########
memory_on_works ()
{
if [ `echo $?` -ne 0 -o `lsmem -a | grep $BLOCK | grep -c yes` -ne 1 ]; then
	echo "Line $LINENO - failed setting memory online Commmand was: chmem -"$COMMAND $BLOCK
	echo "Memory has following status: `lsmem -a | grep $BLOCK`"
	echo " "
fi
}

# Check if setting memory offline worked
########
memory_off_works ()
{
if [ `echo $?` -ne 0 -o `lsmem -a | grep $BLOCK | grep -c offline` -ne 1 ]; then
	echo "Line $LINENO - failed setting memory offline Commmand was: chmem -"$COMMAND $BLOCK
	echo "Memory has following status:"
	echo " "
	echo `lsmem -a | grep $BLOCK`
	echo " "
fi
}

calc_memory ()
{
CONF_BLOCKS_ONLINE_MB=`lsmem -a | grep yes | awk '{print $2}' | awk '{s+=$1}END{print s}'`
if [ "$CONF_BLOCKS_ONLINE_MB" == "" ]; then
        let CONF_BLOCKS_ONLINE_MB=0
fi

CONF_BLOCKS_OFFLINE_MB=`lsmem -a | grep "offline.*-" | awk '{print $2}' | awk '{s+=$1}END{print s}'`
if [ "$CONF_BLOCKS_OFFLINE_MB" == "" ]; then
	let CONF_BLOCKS_OFFLINE_MB=0
fi

ALL_CONF_MB=$(($CONF_BLOCKS_ONLINE_MB + $CONF_BLOCKS_OFFLINE_MB))

echo "Re-Calculating memory"
echo "Memory configurable and online " $CONF_BLOCKS_ONLINE_MB
echo "Memory configurable but offline" $CONF_BLOCKS_OFFLINE_MB
echo "Memory configurable online and offline at start time:" $ALL_CONF_MB_INIT
echo "Memory configurable online and offline total:" $ALL_CONF_MB

}

echo "Memory at beginning of test"
lsmem

while [ `date '+%s'` -lt `expr 60 \* $RUNTIME + $START_TIME` ]; do
	RND=$[($RANDOM % $COUNT) + 1]  # Random between 1 and max. number of memory blocks
	COMMAND=`echo $ACTIONS | awk '{print $'$[($RANDOM % 2) + 1]' }'`
	BLOCK=`echo $CONF_BLOCKS | awk '{print $'$RND'}'`
	echo /root/util-linux-master/chmem -$COMMAND $BLOCK
	chmem -$COMMAND $BLOCK
	sleep 0.1

	if [ "$COMMAND" = "e" ]; then
		memory_on_works
	fi

	if [ "$COMMAND" = "d" ]; then
		memory_off_works
	fi

	calc_memory

	 if [ $ALL_CONF_MB_INIT -gt $ALL_CONF_MB -a $ALL_CONF_MB -gt 0 ]; then
		echo -e "\033[1;3;35mYou have `expr $ALL_CONF_MB_INIT - $CONF_BLOCKS_ONLINE_MB - $CONF_BLOCKS_OFFLINE_MB` MB less configurable memory than when you have started\033[0m"
	fi

	while [ $ALL_CONF_MB -eq 0 ]; do
		NO_CONF_MEM_COUNT=$(($NO_CONF_MEM_COUNT + 1))
		assert_warn 0 0 "Caution - no more configurable memory left after $NO_CONF_MEM_COUNT retrie(s) ..."
		sleep 10

		calc_memory

		if [ $NO_CONF_MEM_COUNT	-gt 120 ]; then
			assert_warn 0 1 "No configurable memory available. Retries: $NO_CONF_MEM_COUNT"
		        echo "Memory configurable and online " $CONF_BLOCKS_ONLINE_MB
		        echo "Memory configurable but offline" $CONF_BLOCKS_OFFLINE_MB
		        echo "Memory configurable online and offline at start time:" $ALL_CONF_MB_INIT
		        echo "Memory configurable online and offline total:" $ALL_CONF_MB
			end_section 0
			exit 1
		fi
	done
NO_CONF_MEM_COUNT=0
done

logger "chmem tests completed sucessfuly at `date`"

assert_warn 0 0 "Test ended sucessfuly"
assert_warn 0 0 "Final memory settings:"
assert_warn 0 0 "You have non-configurable main storage with a total size of $NON_CONF_BLOCKS_TOT_MB MB"
assert_warn 0 0 "Test end configurable memory but offline:" $CONF_BLOCKS_OFFLINE_MB "MB"
assert_warn 0 0 "Test end configurable memory and online: " $CONF_BLOCKS_ONLINE_MB "MB"
assert_warn 0 0 "Test end configurable memory total:      " $ALL_CONF_MB "MB"

# Display the Summary
show_test_results

end_section 0

echo "Memory at end of the test"
lsmem

start_section 0 "Starting cleanup - setting memoryback online"

init_tests

for CONF_BLOCK in $CONF_BLOCKS; do
	chmem -e $CONF_BLOCK
done
assert_warn 0 0 "Cleanup completed"

# Display the Summary
show_test_results

end_section 0
