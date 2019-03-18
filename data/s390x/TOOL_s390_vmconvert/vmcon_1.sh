# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
for f in lib/*.sh; do source $f; done

########################### Cleanup ##################
######################################################
cleanup ()
{
	echo "Cleanup/remove files";
	vmur purge -f &> /dev/null
	rm /root/searchfile.txt &> /dev/null
	rm /root/vmdump.dmp &> /dev/null
	rm /root/converted_dump.lkcd &> /dev/null
	rm /root/crash_out.txt &> /dev/null
}

########################### Create VMdump ############
######################################################
createvmdump ()
{
	echo "Create VM dump";
	if [ "$( grep -c z/VM /proc/sysinfo)" -eq 0 ]; then
		modprobe vmur   # We are on LPAR know
		RET=$?
		assert_warn 0 0 "Trying to load vmur in LPAR, which fails. Ending test in LPAR successfully"
		cleanup
		section_end
		exit 0
	else
		modprobe vmur   # We are on Z/M now
		RET=$?
		assert_warn 0 $RET "Loading vmur on z/VM guest"
		if [ $RET != 0 ]; then
			cleanup;
			section_end;
			exit 1;
		fi
	fi

	# Setting the virtual unit record devices online
	chccwdev -e c # set online attribute in /sys/bus/ccw/devices/0.0.000c
	chccwdev -e d # set online attribute in /sys/bus/ccw/devices/0.0.000d
	chccwdev -e e # set online attribute in /sys/bus/ccw/devices/0.0.000e


	if [ "$( grep -c z/VM /proc/sysinfo)" -eq 0 ]; then
		vmur purge -f # We are on LPAR now
		assert_warn 0 0 "Trying to purge all files from reader - this must fail in LPAR"
		cleanup
		section_end
		exit 0
	else
		vmur purge -f # We are on z/VM now
		if [ $RET != 0 ]; then
			cleanup;
			section_end;
			exit 1;
		fi

		if [ "$(vmur li | grep -c "NO RDR FILES")" -ne 1 ];then
			assert_warn 0 1 "All reader files could be purged"
			cleanup
			section_end
			exit 1
		fi
	fi

	vmcp vmdump
	RET=$?
	assert_warn 0 $RET "creating guest machine dump to z/VM reader"
	if [ $RET != 0 ]; then
		cleanup;
		section_end;
		exit 1;
	fi
}

########################### checkdump with lcrash ###########
#############################################################
checkdump_lcrash ()	# for ... you guessed it ... lcrash - not used upstream anymore since lcrash is not supported anymore
{
	cat <<-EOF > /root/searchfile.txt
	DUMP INFORMATION
	LCRASH CORE FILE REPORT
	COREFILE SUMMARY
	UTSNAME INFORMATION
	LOG BUFFER DUMP
	CURRENT SYSTEM TASKS
	STACK TRACE OF FAILING TASK
	TASK HAS CPU (0)
	EOF

	# lcrash is not supported anymore for Kernels 2.6.34 and up
	if [ "$(lcrash -r "/boot/System.map-$KERNEL_LEVEL" -r "/root/converted_dump.lkcd" "/boot/Kerntypes-$KERNEL_LEVEL" | grep -c -f "/root/searchfile.txt")" -ne 8 ]; then
		assert_warn 0 1 "lcrash -r providing the expected output"
		cleanup;
		section_end;
		exit 1;
	fi
}

########################### checkdump with crash ##################
###################################################################
checkdump ()	# for using crash
{
	# Providing a file with a collection of crash ommands which we execute later ...
	cat <<-EOF > /root/crash_input.txt
	bt -a
	sys
	task
	net
	mach
	dev
	files
	log
	mod
	mount
	ps
	runq
	swap
	vm
	exit
	EOF

	# Providing a file with search patterns to verify crash actually executed those comands
	cat <<-EOF > /root/searchfile.txt
	DEBUGINFO
	CPUS
	TASK
	PID
	task_struct
	MODULE
	FILENAME
	EOF

	# Check if vmlinux.debug (installed with dbginfo package

	[ "$(ls $VMLINUX_DBG)" ]
	RET=$?
	echo "RET: $RET"
	assert_warn 0 $RET "Is $VMLINUX_DBG there? If not please install the package debuginfo which you likely may find at tuxmaker in bb-lab-initfs-addons"
	if [ $RET != 0 ]; then
		cleanup;
		section_end;
		exit 1;
	fi

	# Perform crash with a list of commands (in file /root/crash_input.txt)
	rm /root/crash_out.txt &> /dev/null # delete crash_out.txt to be completely sure we don't pick the wrong one

	# List with which files we will work
	assert_warn 0 0 "Assuming vmlinux in /boot is here: $VMLINUX_BOOT"
	assert_warn 0 0 "Assuming vmlinux.debug is here:    $VMLINUX_DBG"

	# execute crash with the hopefully correct parameteres
	crash -i /root/crash_input.txt $VMLINUX_BOOT $VMLINUX_DBG /root/converted_dump.lkcd >& /root/crash_out.txt
	RET=$?
	assert_warn 0 $RET "Calling crash and reading out the basics of the dump (crash -r = Report)"
	echo "Executed the following command: crash -i /root/crash_input.txt $VMLINUX_BOOT $VMLINUX_DBG /root/converted_dump.lkcd >& /root/crash_out.txt"
	if [ $RET != 0 ]; then
		cleanup;
		section_end;
		exit 1;
	fi

	# I want to have listed crash's output so that it can be verified in the output
	assert_warn 0 0 "$(cat /root/crash_out.txt)"
	RET=$?
	assert_warn 0 $RET "Listing the output of crash to be able to verify visually also"
	if [ $RET != 0 ]; then
		cleanup;
		section_end;
		exit 1;
	fi

	# Lets do a basic plausibiliuty check to see if it 'could' be that it works ;-)
	if [ "$(grep -c -f /root/searchfile.txt /root/crash_out.txt)" -lt 8 ]; then
		assert_warn 0 1 "Plausibility check of crash output"
		cleanup;
		section_end;
		exit 1;
	else
		assert_warn 0 0 "Plausibility check of crash output"
	fi
}

################################################################################