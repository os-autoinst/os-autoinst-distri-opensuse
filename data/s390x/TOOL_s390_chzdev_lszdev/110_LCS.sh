# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 110_LCS.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f lcs.conf
	chzdev $LCS -y --remove-all
	chzdev $LCS -y -d
	chchp -v 0 $LCS_CHPID
	chchp -c 0 $LCS_CHPID
}

isVM
if [[ $? -ne 0 ]];then
start_section 0 "110 LCS test"

if grep -q 110_LCS omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi
		lcs_ifname=`cat lcs_ifname`

		chchp -v 1 $LCS_CHPID
		chchp -c 1 $LCS_CHPID
		sleep 10
		#device online and displayed as persistent online and active online?
		sleep 10; ifconfig -a | grep $lcs_ifname
		assert_fail $? 0 "LCS $LCS is online"

		lszdev $LCS --online | grep $LCS
		assert_warn $? 0 "Active configuration online"

		lszdev $LCS --configured | grep $LCS
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $LCS -i | grep lancmd_timeout | awk '{print $2}' | grep 6
		assert_warn $? 0 "lancmd_timeout=6"

		#change device driver configuration (#2) (nothing to do here for LCS)
		#detach device
			#assert_exec 0 "chchp -c 0 $LCS_CHPID"
			#assert_exec 0 "chchp -v 0 $LCS_CHPID"
			##device offline and displayed as persistent online and active online?
			#sleep 10; ifconfig -a | grep $LCS_IN
			#assert_fail $? 1 "LCS $LCS is offline"

			#lszdev $LCS --online | grep $LCS
			#assert_warn $? 1 "Active configuration offline"

			#lszdev $LCS --configured | grep $LCS
			#assert_warn $? 0 "Persistent configuration online"
			##re-atach device
			#assert_exec 0 "chchp -c 1 $LCS_CHPID"
			#assert_exec 0 "chchp -v 1 $LCS_CHPID"
		#device online and displayed as persistent online and active online?
		#sleep 10; ifconfig -a | grep $LCS_IN
		#assert_fail $? 0 "LCS $LCS is online"

		#lszdev $LCS --online | grep $LCS
		#assert_warn $? 0 "Active configuration online"

		#lszdev $LCS --configured | grep $LCS
		#assert_warn $? 0 "Persistent configuration online"
		#device driver configuration (#2) ? nothing to do for LCS

		#change device and device driver configuration (#3
		assert_exec 0 "chzdev $LCS lancmd_timeout=5"
		lszdev $LCS -i | grep lancmd_timeout | grep 5
		assert_warn $? 0 "lancmd_timeout=5"

		assert_exec 0 "chzdev $LCS -y --remove-all"

        assert_exec 0 "lsmod | grep -q lcs"

		if [[ $? -ne 0 ]];then
			#unload device drivers
			assert_exec 0 "modprobe -r lcs"
			#device offline and displayed as persistent online and active online?
			sleep 10; ifconfig -a | grep $lcs_ifname
			assert_fail $? 1 "LCS $LCS is offline"

			lszdev $LCS --online | grep $LCS
			assert_warn $? 1 "Active configuration offline"

			lszdev $LCS --configured | grep $LCS
			assert_warn $? 0 "Persistent configuration online"
			#reload device drivers
			assert_exec 0 "modprobe lcs"
		else
			assert_exec 0 "chzdev $LCS -y -d"
			assert_exec 0 "chzdev $LCS -e"
		fi
		#device online and displayed as persistent online and active online?
		sleep 10; ifconfig -a | grep $lcs_ifname
		assert_fail $? 0 "LCS $LCS is online"

		lszdev $LCS --online | grep $LCS
		assert_warn $? 0 "Active configuration online"

		lszdev $LCS --configured | grep $LCS
		assert_warn $? 0 "Persistent configuration online"

		#device and device driver configuration (#3) ?
		lszdev $LCS -i | grep lancmd_timeout | grep 5
		assert_warn $? 0 "lancmd_timeout=5"
		#device persistent off
		assert_exec 0 "chzdev lcs $LCS -y -p -d"
		#device online and displayed as persistent offline and active online?
		sleep 10; ifconfig -a | grep $lcs_ifname
		assert_fail $? 0 "LCS $LCS is online"

		lszdev $LCS --online | grep $LCS
		assert_warn $? 0 "Active configuration online"

		lszdev $LCS --configured | grep $LCS
		assert_warn $? 1 "Persistent configuration offline"
		#detach device
		assert_exec 0 "chchp -c 0 $LCS_CHPID"
		assert_exec 0 "chchp -v 0 $LCS_CHPID"

		#device offline and displayed as persistent offline and active online?
		sleep 10; ifconfig -a | grep $lcs_ifname
		assert_fail $? 1 "LCS $LCS is offline"

		lszdev $LCS --online | grep $LCS
		assert_warn $? 1 "Active configuration offline"

		lszdev $LCS --configured | grep $LCS
		assert_warn $? 1 "Persistent configuration offline"
		#re-attach device
		assert_exec 0 "chchp -c 1 $LCS_CHPID"
		assert_exec 0 "chchp -v 1 $LCS_CHPID"
		sleep 30
		#load configuration
		assert_exec 0 "chzdev --import lcs.conf"
		#device online and displayed as persistent online and active online?
		sleep 10; ifconfig -a | grep $lcs_ifname
		assert_fail $? 0 "LCS $LCS is online"

		lszdev $LCS --online | grep $LCS
		assert_warn $? 0 "Active configuration online"

		lszdev $LCS --configured | grep $LCS
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $LCS -i | grep lancmd_timeout | awk '{print $2}' | grep 6
		assert_warn $? 0 "lancmd_timeout=6"

end_section 0

clean

fi
exit 0
