# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

# Load testlib
for f in lib/*.sh; do source $f; done


cleanup(){
 true;
}


disable_cpu()
{
        start_section 1 "set cpu to offline and verify"
	CPUNO=`lscpu -e | tail -1 | cut -d" " -f1`
	checklines=`lscpu -e | wc -l`
	if [ $checklines -le 2 ]
	then
		assert_warn 1 0 "Need minimum of 2 cpus. Increase the cpus and try again"
	else
	   i=3
           while [[ $i -le $checklines ]]
           do
                CPUNO=$((i-2))
		echo lscpu -e
	        lscpu -e
		echo chcpu -d ${CPUNO}
		chcpu -d ${CPUNO}
	        echo lscpu -e
	        lscpu -e
                cat /sys/devices/system/cpu/cpu${CPUNO}/online | grep 0 > /dev/null
		assert_warn $? 0 "cpu $CPUNO set to offline and verified by sysfs attribute"
		i=$((i+1))
	   done
	fi
        end_section 1
}

enable_cpu()
{
        start_section 1 "set cpu to online and verify"
        checklines=`lscpu -e | wc -l`
        if [ $checklines -le 2 ]
        then
                assert_warn 1 0 "Need minimum of 2 cpus. Increase the cpus and try again"
        else
	   i=3
           while [[ $i -le $checklines ]]
           do
                CPUNO=$((i-2))
                echo lscpu -e
                lscpu -e
		echo chcpu -e ${CPUNO}
		chcpu -e ${CPUNO}
                echo lscpu -e
                lscpu -e
                cat /sys/devices/system/cpu/cpu${CPUNO}/online | grep 1 > /dev/null
		assert_warn $? 0 "cpu set to offline and verified by sysfs attribute"
		i=$((i+1))
	   done
        fi
        end_section 1
}


rescan_cpu()
{

        start_section 1 "chcpu rescan"
        checklines=`lscpu -e | wc -l`
        if [ $checklines -gt 3 ]
        then
#		vmcp det cpu 2-$checklines
		assert_warn $? 0 "More than 2 cpus present. Remove them manually and rerun test"
	    else
		echo vmcp define cpu 2-3
		vmcp define cpu 2-3
		assert_warn $? 0 "cpu 2 and 3 defined"
		newchecklines=`lscpu -e | wc -l`
		echo $newchecklines | grep $checklines > /dev/null
		assert_warn $? 0 "cpu 2 and 3 defined are not avaliable to OS"
		echo chcpu -r
		chcpu -r
		echo lscpu -e
		lscpu -e
		newchecklines=`lscpu -e | wc -l`
		echo $newchecklines | grep $checklines > /dev/null
		assert_warn $? 1 "cpu 2 and 3 defined are avaliable to OS"
	fi
	end_section 1
}

set_cpu_polarization()
{
        start_section 1 "set cpu polorization and verify"
        CPUNO=`lscpu -e | tail -1 | cut -d" " -f1`
        lscpu -e | head -2 | tail -1 | grep horizontal > /dev/null
	if [ $? -eq 1 ]
        then
		echo chcpu -p horizontal
	        chcpu -p horizontal
		sleep 20s
	        echo lscpu -e
		lscpu -e
                cat /sys/devices/system/cpu/cpu${CPUNO}/polarization | grep horizontal > /dev/null
		assert_warn $? 0 "polarization set to horizontal and verified by sysfs attribute"
		echo chcpu -p vertical
                chcpu -p vertical
		sleep 20s
	        echo lscpu -e
		lscpu -e
                cat /sys/devices/system/cpu/cpu${CPUNO}/polarization | grep vertical > /dev/null
		assert_warn $? 0 "polarization set to vertical and verified by sysfs attribute"
	 else
                echo chcpu -p vertical
		chcpu -p vertical
		sleep 20s
	        echo lscpu -e
		lscpu -e
                cat /sys/devices/system/cpu/cpu${CPUNO}/polarization | grep vertical > /dev/null
		assert_warn $? 0 "polarization set to vertical and verified by sysfs attribute"
                echo chcpu -p horizontal
	        chcpu -p horizontal
		sleep 20s
		echo lscpu -e
                lscpu -e
                cat /sys/devices/system/cpu/cpu${CPUNO}/polarization | grep horizontal > /dev/null
		assert_warn $? 0 "polarization set to horizontal and verified by sysfs attribute"
		fi
	end_section 1
}

set_cpu_configure_deconfigure()
{
        start_section 1 "cpu configure and deconfigure verify"
        CPUNO=`lscpu -e | tail -1 | cut -d" " -f1`
	CPUDOS=`lscpu -e | tail -2 | cut -d" " -f1 | awk 'NR==1'`

	checklines=`lscpu -e | wc -l`
	checklines=`expr $checklines - 1`

        if [ $checklines -le 2 ]
        then
                assert_warn 1 0 "Need minimum of 2 cpus. Increase the cpus and try again"
        else
	  i=4
	  while [[ $i -le $checklines ]]
	  do
		CPUNO=$((i-2))
		CPUDOS=$((i-1))

		start_section 2 "cpu $CPUNO deconfigure and verify"
                echo lscpu -e
                lscpu -e

	        echo chcpu -d $CPUNO
                chcpu -d $CPUNO

		echo chcpu -d $CPUDOS
                chcpu -d $CPUDOS

		echo lscpu -e
                lscpu -e
                lscpu -e=online,cpu | grep $CPUNO | grep no
                assert_warn $? 0 "cpu $CPUNO set to offline and verified by lscpu"
		sleep 2

		echo chcpu -g $CPUNO
		chcpu -g $CPUNO
                sleep 2
                echo lscpu -e
                lscpu -e

                cat /sys/devices/system/cpu/cpu${CPUNO}/configure | grep 0
                assert_warn $? 0 "cpu $CPUNO is deconfigured and verified by sysfs attribute"
		end_section 2

	        start_section 2 "configure cpu $CPUNO and verify"
                echo chcpu -c $CPUNO
                chcpu -c $CPUNO
		echo lscpu -e
                lscpu -e
		cat /sys/devices/system/cpu/cpu${CPUNO}/configure | grep 1
                assert_warn $? 0 "cpu $CPUNO is configured and verified by sysfs attribute"
                sleep 2
                echo chcpu -e $CPUNO
                chcpu -e $CPUNO
                sleep 2
                echo lscpu -e
                lscpu -e
                lscpu -e=online,cpu | grep $CPUNO | grep yes
                assert_warn $? 0 "cpu set to online and verified by lscpu"
                end_section 2
		i=$((i+1))
	  done
	   fi
        end_section 1
}


lscpu_option_h()
{
	start_section 1 "lscpu -h"
	echo lscpu -h
	lscpu -h
	assert_warn $? 0 "lscpu -h is successfull"
	echo lscpu --help
	lscpu --help
	assert_warn $? 0 "lscpu --help is successfull"
	end_section 1
}


lscpu_option_v()
{
        start_section 1 "lscpu -V"
        echo lscpu -V
        lscpu -V
        assert_warn $? 0 "lscpu -V is successfull"
        echo lscpu --version
        lscpu --version
        assert_warn $? 0 "lscpu --version is successfull"
        end_section 1
}


#############################################################
#main

start_section 0 "START: Test options of chcpu"
init_tests
disable_cpu
enable_cpu

isVM
if [ $? -eq 0 ]
then
	assert_warn 0 0 "On z/VM Polarization, Configure and DeConfigure is not supported"
	if [ $checklines -le 2 ]
        then
                assert_warn 1 0 "Need minimum of 2 cpus. Increase the cpus and try again"
	else
		rescan_cpu
	fi
else
	set_cpu_polarization
	set_cpu_configure_deconfigure
fi
lscpu_option_h
lscpu_option_v


show_test_results
end_section 0
