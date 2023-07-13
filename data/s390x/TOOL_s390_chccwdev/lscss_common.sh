# Copyright 2018 IBM Corp.
# SPDX-License-Identifier: FSFAP


#!/bin/bash
#set -x
DEVELOPMENTMODE="yes"

for f in lib/*.sh; do source $f; done

function call_lscss(){
    start_section 0 "----------Tools like lscss and chccwdev----------"
    start_section 1 "----------lscss---------"
    z=1
    lscss
    assert_warn $? 0 ":(( >> Checking lscss"

    echo "Checking lscss -s......"
    sleep 2
    x=`lscss -d 0.0.0000-0.0.ffff| wc -l`
    x=`expr $x - 2`
    y=`lscss -s | wc -l`
    y=`expr $y - 2`

    if [[ $x -eq $y ]]
    then
        echo "lscss -s"
        lscss -s
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_fail $z 0 ":(( >> Test Case failed"
    fi

    x=`lscss | wc -l`
    x=`expr $x - 2`

    y=`lscss -t | wc -l`
    y=`expr $y - 2`

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



    y=`lscss -t 3390/0C,1732/01 | wc -l`
    y=`expr $y - 2`

    if [[ `lscss | grep -E -i '1732/01|3390/0C' | wc -l` -eq $y ]]
    then
        echo "lscss -t 3390/0C,1732/01"
        sleep 2
        lscss -t 3390/0C,1732/01
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_fail $z 0 ":(( >> Test Case failed"
    fi

    y=`lscss -s -t 3390/0C,1732/01 | wc -l `
    y=`expr $y - 2`
    x=`lscss -s | grep -E -i '1732/01|3390/0C' | wc -l`
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

    y=`lscss -t 3390/0C,1732/01 -s | wc -l`
    y=`expr $y - 2`

    if [[ $x -eq $y ]]
    then
        echo "lscss -t 3390/0C,1732/01 -s"
        lscss -t 3390/0C,1732/01 -s
        assert_warn $z 1 ":(( >> Checking lscss"
    else
        assert_fail $z 0 ":(( >> Test Case failed"
    fi

    end_section 1
}

function call_chccwdev() {
    #set -x
    start_section 1 "-----------chccwdev---------"
    modprobe vmcp >> /dev/null 2>&1
    z=`cat /proc/sysinfo | grep 'VM00 Name'  | awk '{print $3}'`
    vmcp att $1 to $z >> /dev/null 2>&1

    echo " "
    echo "Checking chccwdev"

    for ((  i = 0 ;  i <= 10;  i++  ))
    do
        ls > /dev/null
        #chccwdev -d $1 # >> /dev/null 2>&1
        assert_exec 0 "chccwdev -d $1"
        sleep 1
        echo " "
        assert_exec 0 "chccwdev -e $1"
        sleep 1
    done
    chccwdev -d $1 >> /dev/null 2>&1
    end_section 1
    end_section 0
}
