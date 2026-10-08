# Copyright 2018 IBM Corp.
# SPDX-License-Identifier: FSFAP


#!/bin/bash

# This script verifies the functioning of CHCCWDEV Tool
# Focus on chccwdev -e/-a/-d/-v on DASD, zfcp, qeth,
#chccwdev -e $dasd1

for f in lib/*.sh; do source $f; done

showConfiguration() {
	printf "%20s = %20s\n" "DASD1" "$dasd1";
	printf "%20s = %20s\n" "DASD2" "$dasd2";
}

call_lscss(){
    z=1
    lscss
    assert_warn $? 0 ":(( >> Checking lscss"

    echo "Checking lscss -s......"
    sleep 2
    x="$(lscss -d 0.0.0000-0.0.ffff| wc -l)";
    x="$(( x - 2 ))";
    y="$(lscss -s | wc -l)";
    y="$(( y - 2 ))";

    if [[ $x -eq $y ]]
    then
        echo "lscss -s"
        lscss -s
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_fail $z 0 ":(( >> Test Case failed"
    fi

    x="$(lscss | wc -l)";
    x="$(( x - 2 ))";

    y="$(lscss -t | wc -l)";
    y="$(( y - 2))";

    echo "Checking lscss -t......"
    sleep 2
    if [[ $x -eq $y ]]
    then
        echo "lscss -t"
        lscss -t
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_warn $z 0 ":(( >> Test Case failed"
    fi



    y="$(lscss -t 3390/0C,1732/01 | wc -l)";
    y="$(( y - 2))";

    if [[ "$(lscss | grep -E -i '1732/01|3390/0C' | wc -l)" -eq $y ]]
    then
        echo "lscss -t 3390/0C,1732/01"
        sleep 2
        lscss -t 3390/0C,1732/01
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_fail $z 0 ":(( >> Test Case failed"
    fi

    y="$(lscss -s -t 3390/0C,1732/01 | wc -l )";
    y="$(( y - 2 ))";
    x="$(lscss -s | grep -E -i '1732/01|3390/0C' | wc -l)";
    #x=`expr $x - 2`

    if [[ $x -eq $y ]]
    then
        echo "lscss -s -t 3390/0C,1732/01"
        sleep 2
        lscss -s -t 3390/0C,1732/01
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_fail $z 0 ":(( >> Test Case failed"
    fi

    y="$(lscss -t 3390/0C,1732/01 -s | wc -l)";
    y="$(( y - 2 ))";

    if [[ $x -eq $y ]]
    then
        echo "lscss -t 3390/0C,1732/01 -s"
        lscss -t 3390/0C,1732/01 -s
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_fail $z 0 ":(( >> Test Case failed"
    fi
}

isDASDReadOnly() {
    local BUSID="$1";
    if [[ "${#BUSID}" == 4 ]]; then
        BUSID="0.0.${BUSID}";
    fi
    if [ ! -d "/sys/bus/ccw/devices/${BUSID}" ]; then
        echo "sysfs path '/sys/bus/ccw/devices/${BUSID}' does not exist." >&2;
    fi
    [[ "$(cat "/sys/bus/ccw/devices/${BUSID}/readonly" 2>/dev/null)" == 1 ]];
    return $?;
}

verifyBasicOptions() {
	echo "Verify on/off";
	for (( i = 0 ; i <= 10; i++ )); do
		assert_exec 0 "chccwdev -d $dasd1";
		sleep 1;
		assert_exec 0 "chccwdev -e $dasd1";
		sleep 1;
	done

	echo "Verify basic options";
	assert_exec 1 "chccwdev --help";
	assert_exec 0 "chccwdev -v"
	assert_exec 0 "chccwdev -a online=0 $dasd1";
	sleep 3
	assert_exec 0 "chccwdev -a online=1 $dasd1";
	sleep 3
	assert_exec 0 "chccwdev -a readonly=1 -a cmb_enable=1 $dasd1";
	sleep 5
	echo "Verify that readonly is set properly";
    isDASDReadOnly "${dasd1}";
	assert_warn $? 0 "DASD $dasd1 is readonly";
	sleep 5
	assert_exec 0 "chccwdev -a readonly=0 -a cmb_enable=0 $dasd1";
	echo "Verify that readonly is removed properly";
    isDASDReadOnly "${dasd1}";
	assert_warn $? 1 "DASD $dasd1 readonly was removed successfully";
	sleep 5
	assert_exec 0 "chccwdev -f $dasd1";
	sleep 5

	if [ -n "$dasd2" ]; then
		echo "Verify chccwdev with 2 devices";
		echo "dasd2=$dasd2";
		assert_exec 0 "chccwdev -e $dasd2";
		sleep 5
		assert_exec 0 "chccwdev -d $dasd1,$dasd2";
		sleep 5
		assert_exec 0 "chccwdev -e $dasd1,$dasd2";
		sleep 5
		assert_exec 0 "chccwdev -d $dasd1,$dasd2";
		sleep 5
	fi
}

verifyErrorConditions() {
	echo "Verify invalid bus id";
	assert_exec 1 "chccwdev -e 0$dasd1";
	echo "Verify invalid attribute";
	assert_exec 1 "chccwdev -a asdf=1234 $dasd1";
	echo "Verify invalid attribute (strncmp)";
	assert_exec 1 "chccwdev -a onlineasdf=1 $dasd1";
	sleep 5
}

################################################################################
# Start
################################################################################

dasd1=$1
dasd2=$2

init_tests;
section_start "Test chccwdev";

if isVM; then
	section_start "z/VM attach dasd";
	modprobe vmcp;
	vmcp att "$dasd1" '*';
	if [ -n "$dasd2" ]; then
		vmcp att "$dasd2" '*';
	fi
	section_end;
fi

section_start "Configuration";
showConfiguration;
section_end;

section_start "Check lscss";
call_lscss;
section_end;

section_start "Verify basic chccwdev options";
verifyBasicOptions;
section_end;

section_start "Verify error conditions with chccwdev";
verifyErrorConditions;
section_end;

show_test_results
section_end
