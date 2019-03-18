# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash

# Load testlib
for f in lib/*.sh; do source $f; done


#functions to perform tests
initial()
{

	start_section 0 "START: zipl.conf with maxcpus as kernel boot parameter"
	start_section 1 "Initial Setup"
	init_tests
	echo "running test for lscpu and chcpu command" > /root/lscpu_chcpu.lock

#	cp /etc/zipl.conf /etc/zipl.conf.orig
#	zipl -V > ziploutfile

    cp /etc/default/grub /etc/default/grub.orig
	assert_warn $? 0 "Initial setup successfull"
	end_section 1
}

cleanup(){
 true;
}


check()
{
    start_section 0 "Verify system reipl"
	init_tests
	if [ -e /root/lscpu_chcpu.lock ]
	then
		assert_warn $? 0 "The system rebooted successfully"
	fi
	#end_section 0
}

test1()
{
	start_section 0 "define more cpus"
	init_tests

	checklines=`lscpu -e | wc -l`
        if [ $checklines -gt 3 ]
        then
               assert_warn 0 0 "There are more than 2 cpus no need to attach"
	else
		vmcp define cpu 2-3
                assert_warn $? 0 "attached 2 cpus "
        fi
}

test2()
{
	start_section 0 "add maxcpus=2 to zipl.conf"
    init_tests

	echo chcpu -r
	chcpu -r

#	sed -i -e 's|parameters="|parameters="maxcpus=2 |i' /etc/zipl.conf
#	echo "cat /etc/zipl.conf"
#        cat /etc/zipl.conf
#        echo "zipl -V"
#        zipl -V

    sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="nr_cpus=2"/' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg

	echo lscpu -e
	lscpu -e
        assert_warn $? 0 "zipl.conf is added with maxcpus=2 successfully"
	show_test_results
	end_section 0
	#reboot
}


test3()
{
	start_section 0 ""
	init_tests
	echo lscpu -e
       lscpu -e
	lscpu -e=cpu,online| grep yes | wc -l | grep 2 > /dev/null
       assert_warn $? 0 "The system is booted with 2 cpus successfully"
#	cp /etc/zipl.conf.orig /etc/zipl.conf
#       echo "zipl -V"
#       zipl -V

}


end()
{
        start_section 0 "Cleanup"
	init_tests
#	cp /etc/zipl.conf.orig /etc/zipl.conf
#	zipl -V
#	rm -f ziploutfile /etc/zipl.conf.orig /root/lscpu_chcpu.lock
    cp /etc/default/grub.orig /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg

    assert_warn $? 0 "cleanup successful"
	#end_section 0
}


#############################################################
#main

#start_section 0 "START: zipl.conf with maxcpus as kernel boot parameter"
#init_tests

case $1 in
	start)	initial
		;;
	test1)	test1
		;;
	test2)	test2
		;;
	test3)	test3
		;;
	check)	check
		;;
	end)	end
		;;
	*)	assert_warn 1 0 "Unknown option"
		exit 1
		;;
esac

show_test_results
end_section 0
