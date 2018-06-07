# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

# Load testlib
for f in lib/*.sh; do source $f; done
source ./test_lscpu_1.sh || exit 1



set_cpu_online_verify_with_lscpu()
{
        start_section 1 "set cpu to online and verify"
        checklines=`lscpu -e | wc -l`
        if [ $checklines -le 2 ]
        then
                assert_warn 1 0 "Need minimum of 2 cpus. Increase the cpus and try again"
        else
                echo lscpu -e
                lscpu -e
                CPUNO=`lscpu -e | tail -1 | cut -d" " -f1`
                echo "echo 1 > /sys/devices/system/cpu/cpu${CPUNO}/online"
                echo 1 > /sys/devices/system/cpu/cpu${CPUNO}/online
                echo lscpu -e
                lscpu -e
                lscpu -e=online|tail -1|grep yes
                assert_warn $? 0 "cpu set to online and verified by lscpu"
        fi
        end_section 1
}


set_cpu_polarization()
{
        start_section 1 "set cpu polorization and verify"
        lscpu -e | head -2 | tail -1 | grep horizontal
	if [ $? -eq 1 ]
        then
		echo chcpu -p horizontal
	        chcpu -p horizontal
		sleep 20s
	        echo lscpu -e
		lscpu -e
		lscpu -e=polarization | grep horizontal
		assert_warn $? 0 "cpu polarization set to horizontal"
		echo chcpu -p vertical
                chcpu -p vertical
		sleep 20s
	        echo lscpu -e
		lscpu -e
		assert_warn $? 0 "cpu polarization set to vertical"
	 else
                echo chcpu -p vertical
		chcpu -p vertical
		sleep 20s
	               echo lscpu -e
		        lscpu -e
			assert_warn $? 0 "cpu polarization set to vertical"
			echo chcpu -p horizontal
	                chcpu -p horizontal
			sleep 20s
		        echo lscpu -e
			lscpu -e
			lscpu -e=polarization | grep horizontal
			assert_warn $? 0 "cpu polarization set to horizontal"
		fi
	end_section 1
}

set_cpu_configure_deconfigure()
{
        start_section 1 "cpu configure and deconfigure verify"
	   checklines=`lscpu -e | wc -l`
           if [ $checklines -le 2 ]
           then
                assert_warn 1 0 "Need minimum of 2 cpus. Increase the cpus and try again"
           else
		start_section 2 "cpu deconfigure and verify"

		CPUNO=`lscpu -e | tail -2 | cut -d" " -f1 | awk 'NR==2'`
                echo "echo 0 > /sys/devices/system/cpu/cpu${CPUNO}/online"
                echo 0 > /sys/devices/system/cpu/cpu${CPUNO}/online

		CPUDOS=`lscpu -e | tail -2 | cut -d" " -f1 | awk 'NR==1'`
                echo "echo 0 > /sys/devices/system/cpu/cpu${CPUDOS}/online"
                echo 0 > /sys/devices/system/cpu/cpu${CPUDOS}/online

		echo lscpu -e
                lscpu -e
                lscpu -e=online|tail -1|grep no
                assert_warn $? 0 "cpu set to offline and verified by lscpu"
		sleep 2
                echo "echo 0 > /sys/devices/system/cpu/cpu${CPUNO}/configure"
                echo 0 > /sys/devices/system/cpu/cpu${CPUNO}/configure
		sleep 2
		echo "echo 0 > /sys/devices/system/cpu/cpu${CPUDOS}/configure"
                echo 0 > /sys/devices/system/cpu/cpu${CPUDOS}/configure
                sleep 2

		echo lscpu -e
                lscpu -e
                lscpu -e=configured|tail -1|grep no
                assert_warn $? 0 "cpu is deconfigured and verified by lscpu"
		end_section 2

	        start_section 2 "cpu configure and verify"
                echo "echo 1 > /sys/devices/system/cpu/cpu${CPUNO}/configure"
                echo 1 > /sys/devices/system/cpu/cpu${CPUNO}/configure
                echo lscpu -e
                lscpu -e
                lscpu -e=configured|tail -1|grep yes
                assert_warn $? 0 "cpu is configured and verified by lscpu"
                sleep 2
                echo "echo 1 > /sys/devices/system/cpu/cpu${CPUNO}/online"
                echo 1 > /sys/devices/system/cpu/cpu${CPUNO}/online
                sleep 2
                echo lscpu -e
                lscpu -e
                lscpu -e=online|tail -1|grep yes
                assert_warn $? 0 "cpu set to online and verified by lscpu"
                end_section 2
	   fi
        end_section 1
}


lscpu_option_h()
{
	start_section 1 "lscpu -h"
	echo lscpu -h
	lscpu -h
	assert_warn $? 0 "lscpu -h is successfull"
	end_section 1
}


lscpu_option_v()
{
        start_section 1 "lscpu -V"
        echo lscpu -V
        lscpu -V
        assert_warn $? 0 "lscpu -V is successfull"
        end_section 1
}


#############################################################
#main

start_section 0 "START: Test lscpu options"
init_tests
lscpu_option_e
lscpu_option_p
lscpu_option_s
set_cpu_offline_verify_with_lscpu
set_cpu_online_verify_with_lscpu
isVM
if [ $? -eq 0 ]
then
	assert_warn 0 0 "On z/VM Polarization, Configure and DeConfigure is not supported"
else
	set_cpu_polarization
	set_cpu_configure_deconfigure
fi
lscpu_option_h
lscpu_option_v


show_test_results
end_section 0
