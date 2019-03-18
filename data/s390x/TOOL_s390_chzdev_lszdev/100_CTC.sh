# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 20_CTC.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f ctc.conf
	chzdev $CTC -y --remove-all
	chzdev $CTC -d
	chchp -v 0 $CTC_CHPID
	chchp -c 0 $CTC_CHPID
}

isVM
if [[ $? -ne 0 ]];then
start_section 0 "100 CTC test"

if grep -q 100_CTC omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi
		ctc_ifname=`cat ctc_ifname`

		chchp -v 1 $CTC_CHPID
		chchp -c 1 $CTC_CHPID
		#device online and displayed as persistent online and active online?
		sleep 10
		ifconfig -a | grep $ctc_ifname
		assert_fail $? 0 "CTC $CTC is online"

		lszdev $CTC --online | grep $CTC_IN
		assert_warn $? 0 "Active configuration online"

		lszdev $CTC --configured | grep $CTC_IN
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $CTC -i | grep buffer | awk '{print $2}' | grep 32769
		assert_warn $? 0 "buffer=32769"

		lszdev $CTC -i | grep protocol | awk '{print $2}' | grep 1
		assert_warn $? 0 "protocol=1"

		#change device driver configuration (#2) (nothing to do here for ctc)
		#detach device
		assert_exec 0 "chchp -c 0 $CTC_CHPID"
		assert_exec 0 "chchp -v 0 $CTC_CHPID"
		#device offline and displayed as persistent online and active offline?
		sleep 10
		ifconfig -a | grep $ctc_ifname
		assert_fail $? 1 "CTC $CTC is offline"

		lszdev $CTC --online | grep $CTC_IN
		assert_warn $? 1 "Active configuration offline"

		lszdev $CTC --configured | grep $CTC_IN
		assert_warn $? 0 "Persistent configuration online"
		#re-atach device
		assert_exec 0 "chchp -c 1 $CTC_CHPID"
		assert_exec 0 "chchp -v 1 $CTC_CHPID"
		sleep 10
		#device online and displayed as persistent online and active online?
		lszdev $CTC --online | grep $CTC_IN
		assert_warn $? 0 "Active configuration online"

		lszdev $CTC --configured | grep $CTC_IN
		assert_warn $? 0 "Persistent configuration online"
		sleep 10
		ifconfig -a | grep $ctc_ifname
		assert_fail $? 0 "CTC $CTC is online"
		#device driver configuration (#2) ? nothing to do for ctc

		#change device and device driver configuration (#3)
		assert_exec 0 "chzdev $CTC -y --remove-all"

		assert_exec 0 "lsmod | grep -q ctcm"

		if [[ $? -ne 0 ]];then
			#unload device drivers
			assert_exec 0 "modprobe -r ctcm"
			sleep 10
			#device offline and displayed as persistent online and active online?
			sleep 10
			ifconfig -a | grep $ctc_ifname
			assert_fail $? 1 "CTC $CTC is offline"

			lszdev $CTC --online | grep $CTC_IN
			assert_warn $? 1 "Active configuration offline"

			lszdev $CTC --configured | grep $CTC_IN
			assert_warn $? 0 "Persistent configuration online"
			#reload device drivers
			assert_exec 0 "modprobe ctcm"
		else
			assert_exec 0 "chzdev $CTC -d"
			assert_exec 0 "chzdev $CTC -e"
		fi
		sleep 10
		#device online and displayed as persistent online and active online?
		ifconfig -a | grep $ctc_ifname
		assert_fail $? 0 "CTC $CTC is online"

		lszdev $CTC --online | grep $CTC_IN
		assert_warn $? 0 "Active configuration online"

		lszdev $CTC --configured | grep $CTC_IN
		assert_warn $? 0 "Persistent configuration online"
		#device and device driver configuration (#3) ?

		#device persistent off
		assert_exec 0 "chzdev ctc $CTC -p -d"
		#device online and displayed as persistent offline and active online?
		sleep 10
		ifconfig -a | grep $ctc_ifname
		assert_fail $? 0 "CTC $CTC is online"

		lszdev $CTC --online | grep $CTC_IN
		assert_warn $? 0 "Active configuration online"

		lszdev $CTC --configured | grep $CTC_IN
		assert_warn $? 1 "Persistent configuration offline"
		#detach device
		assert_exec 0 "chchp -c 0 $CTC_CHPID"
		assert_exec 0 "chchp -v 0 $CTC_CHPID"
		#device offline and displayed as persistent offline and active offline?
		sleep 10
		ifconfig -a | grep $ctc_ifname
		assert_fail $? 1 "CTC $CTC is offline"

		lszdev $CTC --online | grep $CTC_IN
		assert_warn $? 1 "Active configuration offline"

		lszdev $CTC --configured | grep $CTC_IN
		assert_warn $? 1 "Persistent configuration offline"
		#re-attach device
		assert_exec 0 "chchp -c 1 $CTC_CHPID"
		assert_exec 0 "chchp -v 1 $CTC_CHPID"
		sleep 10
		#load configuration
		assert_exec 0 "chzdev --import ctc.conf"
		#device online and displayed as persistent online and active online?
		sleep 10
		ifconfig -a | grep $ctc_ifname
		assert_fail $? 0 "CTC $CTC is online"

		lszdev $CTC --online | grep $CTC_IN
		assert_warn $? 0 "Active configuration online"

		lszdev $CTC --configured | grep $CTC_IN
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $CTC -i | grep buffer | awk '{print $2}' | grep 32769
		assert_warn $? 0 "buffer=32769"

end_section 0
clean
fi
exit 0
