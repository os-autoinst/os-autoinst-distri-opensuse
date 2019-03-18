# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/usr/bin/env bash

for f in lib/*.sh; do source $f; done

assert_cpuplugd_running() {
    local NOT_RUNNING=${1}
    local WARN=${2}

    if [[ ${NOT_RUNNING} -eq 0 ]]; then
        MESSAGE="cpuplugd is running"
    elif [[ ${NOT_RUNNING} -eq 1 ]]; then
        MESSAGE="cpuplugd is not running"
    fi

    ps -e | grep -q cpuplugd
    RC=$?

    if [[ ${WARN} -eq 1 ]]; then
        assert_warn ${RC} ${NOT_RUNNING} "${MESSAGE}"
    fi

    return ${RC}
}

stop_cpuplugd() {
    echo "stop cpuplugd"
    # With Sles15 there is no PID file for cpuplugd
    # when running in the foreground
    # if ( isSles15 ); then
    #     if [ -e /run/cpuplugd.pid ]; then
    #        kill $(cat /run/cpuplugd.pid)
    #     else
    #        kill $(ps -e | grep -i cpuplugd | awk '{print $1}')
    #     fi
    # else
    #     kill $(cat /var/run/cpuplugd.pid)
    # fi
    #########################################################
    # updated start                                   #
    #########################################################
        if [ -e /run/cpuplugd.pid ]; then
           kill $(cat /run/cpuplugd.pid)
    elif [ -e /var/run/cpuplugd.pid ]; then
       kill $(cat /var/run/cpuplugd.pid)
        else
	   kill $(ps -e | grep -i cpuplugd | awk '{print $1}')
        fi
    #########################################################
    # updated end                                     #
    #########################################################

    until ! assert_cpuplugd_running 1 0; do
        echo "cpuplugd is still running"
        sleep 1
    done

    assert_warn $? 0 "cpuplugd is not running"
}

#Function to remove the given entry ($1) from test configuration file
prepare_incomplete_cpu_test_config() {
    rm -rf cpuplugdtest.conf
    cp cpuplugd.conf cpuplugdtest.conf
    sed -e 's/'$1'/#'$1'/' -i cpuplugdtest.conf
}

prepare_incomplete_cmm_test_config() {
    rm -rf cpuplugdtest.conf
    cp cpuplugdcmm.conf cpuplugdtest.conf
    sed -e 's/'$1'/#'$1'/' -i cpuplugdtest.conf
}

#run cpuplgd with cpuplugdtest.conf and verify change in number of cpus before/during/after running the daemon
cpu_test_with_error_in_cpuplgdtest_conf() {
    local NOT_RUNNING=${1}
    local WARN=${2}

    # cmm must not be loaded so that cpuplugd will only consider the cpu configuration
    if [[ "${CMM_MOD}" = "m" ]]; then
        rmmod cmm
    fi

    assert_cpuplugd_running 1 0
    RC=$?

    if [[ ${RC} -eq 0 ]]; then
        stop_cpuplugd
    fi

    cpusbefore=$(grep "processors" /proc/cpuinfo | cut -d":" -f2)
    echo "start cpuplugd -V -c cpuplugdtest.conf -f"
    cpuplugd -V -c cpuplugdtest.conf -f >> cpuf &
    sleep 2

    if [[ "${CMM_MOD}" = "m" ]]; then
        assert_cpuplugd_running ${NOT_RUNNING} ${WARN}
    else
        assert_cpuplugd_running ${NOT_RUNNING} ${WARN}
    fi

    RC=$?

    # Wait a little to allow for (undesired) cpu configuration change
    sleep ${SLEEP_X}
    cpusrunning=$(grep "processors" /proc/cpuinfo | cut -d":" -f2)

    if [[ ${RC} -eq 0 ]]; then
        stop_cpuplugd
    fi

    cpusafter=$(grep "processors" /proc/cpuinfo | cut -d":" -f2)
    i=0

    if (( "$cpusbefore" == "$cpusrunning" )) && (( "$cpusrunning" == "$cpusafter" )); then
        i=1
    fi

    assert_warn $i 1 "Verify that CPU configuration does not change: cpusbefore=$cpusbefore, cpusduring=$cpusrunning, cpusafterter=$cpusafter"
}

#run cpuplgd with cpuplugdtest.conf and verify change in number of cmm pagess before/during/after running the daemon
cmm_test_with_error_in_cpuplgdtest_conf() {
    local NOT_RUNNING=${1}
    local WARN=${2}

    assert_cpuplugd_running 1 0
    RC=$?

    if [[ ${RC} -eq 0 ]]; then
        stop_cpuplugd
    fi

    if [[ "${CMM_MOD}" = "m" ]]; then
        modprobe cmm
    fi

    echo 1000 > /proc/sys/vm/cmm_pages
    sleep 2

    cmm_pages_before=$(cat /proc/sys/vm/cmm_pages)

    echo "start cpuplugd -V -c cpuplugdtest.conf -f"
    cpuplugd -V -c cpuplugdtest.conf -f >> cmm &
    sleep 2

    assert_cpuplugd_running ${NOT_RUNNING} ${WARN}
    RC=$?

    # Wait a little to allow for (undesired) cpu configuration change
    sleep ${SLEEP_X}
    cmm_pages_running=$(cat /proc/sys/vm/cmm_pages)

    if [[ ${RC} -eq 0 ]]; then
        stop_cpuplugd
    fi

    cmm_pages_after=$(cat /proc/sys/vm/cmm_pages)
    i=0

    if (( "$cmm_pages_before" == "$cmm_pages_running" )) && (( "$cmm_pages_running" == "$cmm_pages_after" )); then
        i=1
    fi

    assert_warn ${i} 1  "Verify that the number of available CMM pages does not change: cmm_pages_before=$cmm_pages_before, cmm_pages_running=$cmm_pages_running, cmm_pages_after=$cmm_pages_after"
    if [[ "${CMM_MOD}" = "m" ]]; then
        rmmod cmm
    fi
}
