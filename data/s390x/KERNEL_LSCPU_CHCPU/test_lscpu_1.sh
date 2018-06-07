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


lscpu_option_e()
{
	start_section 1 "lscpu with -e extended readable format"
	checklines=`lscpu -e | wc -l`
	chcpu -c 0-$((checklines-2))
	chcpu -e 0-$((checklines-2))
        start_section 2 "lscpu to display all online, offline cpu"
        echo lscpu -a -e
        lscpu -a -e
        assert_warn $? 0 "lscpu -a -e successfull"
        end_section 2
        start_section 2 "lscpu to display all online cpu"
        echo lscpu -b -e
        lscpu -b -e
        assert_warn $? 0 "lscpu -b -e successfull"
        end_section 2
        start_section 2 "lscpu to display all offline cpu"
        echo lscpu -c -e
        lscpu -c -e
        assert_warn $? 0 "lscpu -c -e successfull"
        end_section 2
        start_section 2 "lscpu to display output in extended format"
        echo lscpu -e
        lscpu -e
        assert_warn $? 0 "lscpu -c -e successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu"
        echo lscpu -e=cpu
        lscpu -e=cpu
        assert_warn $? 0 "lscpu -e=cpu successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu, node"
        echo lscpu -e=cpu,node
        lscpu -e=cpu,node
        assert_warn $? 0 "lscpu -e=cpu,node successfull"
        end_section 2
        start_section 2 "lscpu to display cpu polarization"
        echo lscpu -e=cpu POLARIZATION
        lscpu -e=cpu,node,POLARIZATION
        assert_warn $? 0 "lscpu -e=cpu,POLARIZATION successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured status"
        echo lscpu -e=cpu,POLARIZATION,CONFIGURED
        lscpu -e=cpu,POLARIZATION,CONFIGURED
        assert_warn $? 0 "lscpu -e=cpu,POLARIZATION,CONFIGURED successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured and status"
        echo lscpu -e=cpu,CONFIGURED,ONLINE
        lscpu -e=cpu,CONFIGURED,ONLINE
        assert_warn $? 0 "lscpu -e=cpu,CONFIGURED,ONLINE successfull"
        end_section 2

        end_section 1

}

lscpu_option_p()
{
        start_section 1 "lscpu with -p parsable format"
        start_section 2 "lscpu to display all online, offline cpu"
        echo lscpu -a -p
        lscpu -a -p
        assert_warn $? 0 "lscpu -a -p successfull"
        end_section 2
        start_section 2 "lscpu to display all online cpu"
        echo lscpu -b -p
        lscpu -b -p
        assert_warn $? 0 "lscpu -b -p successfull"
        end_section 2
        start_section 2 "lscpu to display all offline cpu"
        echo lscpu -c -p
        lscpu -c -p
        assert_warn $? 0 "lscpu -c -p successfull"
        end_section 2
        start_section 2 "lscpu to display output in extended format"
        echo lscpu -p
        lscpu -p
        assert_warn $? 0 "lscpu -c -p successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu"
        echo lscpu -p=cpu
        lscpu -p=cpu
        assert_warn $? 0 "lscpu -p=cpu successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu, node"
        echo lscpu -p=cpu,node
        lscpu -p=cpu,node
        assert_warn $? 0 "lscpu -p=cpu,node successfull"
        end_section 2
        start_section 2 "lscpu to display cpu polarization"
        echo lscpu -p=cpu POLARIZATION
        lscpu -p=cpu,node,POLARIZATION
        assert_warn $? 0 "lscpu -p=cpu,POLARIZATION successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured status"
        echo lscpu -p=cpu,POLARIZATION,CONFIGURED
        lscpu -p=cpu,POLARIZATION,CONFIGURED
        assert_warn $? 0 "lscpu -p=cpu,POLARIZATION,CONFIGURED successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured and status"
        echo lscpu -p=cpu,CONFIGURED,ONLINE
        lscpu -p=cpu,CONFIGURED,ONLINE
        assert_warn $? 0 "lscpu -p=cpu,CONFIGURED,ONLINE successfull"
        end_section 2
        end_section 1

}

#if [ -e lscpu_validate_e_option.py ]
#then
#	echo "executing lscpu_validate_e_option.py"
#	./lscpu_validate_e_option.py
#fi

lscpu_option_s()
{
        start_section 1 "lscpu with -s DIR as system root"
        start_section 2 "lscpu to display all online, offline cpu"
        echo lscpu -a -e -s /
        lscpu -a -e -s /
        assert_warn $? 0 "lscpu -a -e -s / successfull"
        end_section 2
        start_section 2 "lscpu to display all online cpu"
        echo lscpu -b -e -s /
        lscpu -b -e -s /
        assert_warn $? 0 "lscpu -b -e -s / successfull"
        end_section 2
        start_section 2 "lscpu to display all offline cpu"
        echo lscpu -c -e -s /
        lscpu -c -e -s /
        assert_warn $? 0 "lscpu -c -e -s / successfull"
        end_section 2
        start_section 2 "lscpu to display output in extended format"
        echo lscpu -e -s /
        lscpu -e -s /
        assert_warn $? 0 "lscpu -c -e -s / successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu"
        echo lscpu -e=cpu -s /
        lscpu -e=cpu -s /
        assert_warn $? 0 "lscpu -e=cpu successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu, node"
        echo lscpu -e=cpu,node -s /
        lscpu -e=cpu,node -s /
        assert_warn $? 0 "lscpu -e=cpu,node successfull"
        end_section 2
        start_section 2 "lscpu to display cpu polarization"
        echo lscpu -e=cpu,POLARIZATION -s /
        lscpu -e=cpu,POLARIZATION -s /
        assert_warn $? 0 "lscpu -e=cpu,POLARIZATION successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured status"
        echo lscpu -e=cpu,POLARIZATION,CONFIGURED -s /
        lscpu -e=cpu,POLARIZATION,CONFIGURED -s /
        assert_warn $? 0 "lscpu -e=cpu,POLARIZATION,CONFIGURED successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured and status"
        echo lscpu -e=cpu,CONFIGURED,ONLINE -s /
        lscpu -e=cpu,CONFIGURED,ONLINE -s /
        assert_warn $? 0 "lscpu -e=cpu,CONFIGURED,ONLINE successfull"
        end_section 2
	start_section 2 "lscpu to display all online, offline cpu"
        echo lscpu -a -p -s /
        lscpu -a -p -s /
        assert_warn $? 0 "lscpu -a -p -s / successfull"
        end_section 2
        start_section 2 "lscpu to display all online cpu"
        echo lscpu -b -p -s /
        lscpu -b -p -s /
        assert_warn $? 0 "lscpu -b -p -s / successfull"
        end_section 2
        start_section 2 "lscpu to display all offline cpu"
        echo lscpu -c -p -s /
        lscpu -c -p -s /
        assert_warn $? 0 "lscpu -c -p -s / successfull"
        end_section 2
        start_section 2 "lscpu to display output in extended format"
        echo lscpu -p -s /
        lscpu -p -s /
        assert_warn $? 0 "lscpu -c -p -s / successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu"
        echo lscpu -p=cpu -s /
        lscpu -p=cpu -s /
        assert_warn $? 0 "lscpu -p=cpu successfull"
        end_section 2
        start_section 2 "lscpu to display only cpu, node"
        echo lscpu -p=cpu,node -s /
        lscpu -p=cpu,node -s /
        assert_warn $? 0 "lscpu -p=cpu,node successfull"
        end_section 2
        start_section 2 "lscpu to display cpu polarization"
        echo lscpu -p=cpu,POLARIZATION -s /
        lscpu -p=cpu,POLARIZATION -s /
        assert_warn $? 0 "lscpu -p=cpu,POLARIZATION successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured status"
        echo lscpu -p=cpu,POLARIZATION,CONFIGURED -s /
        lscpu -p=cpu,POLARIZATION,CONFIGURED -s /
        assert_warn $? 0 "lscpu -p=cpu,POLARIZATION,CONFIGURED successfull"
        end_section 2
        start_section 2 "lscpu to display cpu configured and status"
        echo lscpu -p=cpu,CONFIGURED,ONLINE -s /
        lscpu -p=cpu,CONFIGURED,ONLINE -s /
        assert_warn $? 0 "lscpu -p=cpu,CONFIGURED,ONLINE successfull"
        end_section 2

        end_section 1

}


set_cpu_offline_verify_with_lscpu()
{

        start_section 1 "set cpu to offline and verify"
	checklines=`lscpu -e | wc -l`
	if [ $checklines -le 2 ]
	then
		assert_warn 1 0 "Need minimum of 2 cpus. Increase the cpus and try again"
	else
		echo lscpu -e
	        lscpu -e
		CPUNO=`lscpu -e | tail -1 | cut -d" " -f1`
	        echo "echo 0 > /sys/devices/system/cpu/cpu${CPUNO}/online"
		echo 0 > /sys/devices/system/cpu/cpu${CPUNO}/online
	        echo lscpu -e
	        lscpu -e
		lscpu -e=online|tail -1|grep no
		assert_warn $? 0 "cpu set to offline and verified by lscpu"
	fi
        end_section 1
}