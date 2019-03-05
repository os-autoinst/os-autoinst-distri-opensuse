# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 20_DASD.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f dasd.conf
	chzdev $DASD cmb_enable=0 erplog=0 failfast=0 readonly=0 reservation_policy=ignore
	chzdev --type dasd -y --remove-all
	chzdev $DASD -y --remove-all
	chzdev $DASD -d
	chchp -v 0 $DASD_CHPID
	chchp -c 0 $DASD_CHPID
}

start_section 0 "20 DASD test"

if grep -q 20_DASD omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi

		chchp -v 1 $DASD_CHPID
		chchp -c 1 $DASD_CHPID
		sleep 10
		#device online and displayed as persistent online and active online?
		lsdasd | grep $DASD
		assert_fail $? 0 "DASD $DASD is online"

		lszdev $DASD --online | grep $DASD
		assert_warn $? 0 "Active configuration online"

		lszdev $DASD --configured | grep $DASD
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $DASD -i | grep eer_enabled | awk '{print $2}' | grep 1
		assert_warn $? 0 "eer_enabled=1"

		lszdev $DASD -i | grep erplog | awk '{print $2}' | grep 1
		assert_warn $? 0 "erplog=1"

		lszdev $DASD -i | grep expires | awk '{print $2}' | grep 31
		assert_warn $? 0 "expires=31"

		lszdev $DASD -i | grep failfast | awk '{print $2}' | grep 1
		assert_warn $? 0 "failfast=1"

		lszdev $DASD -i | grep readonly | awk '{print $2}' | grep 1
		assert_warn $? 0 "readonly=1"
		#depends on patch not yet in distro
		if [[ $? -eq 0 ]];then
			lszdev $DASD -i | grep timeout | awk '{print $2}' | grep 999
			assert_warn $? 0 "timeout=999"

			lszdev $DASD -i | grep retries | awk '{print $2}' | grep 999
			assert_warn $? 0 "retries=999"
		fi
		lszdev $DASD -i | grep reservation_policy | awk '{print $2}' | grep fail
		assert_warn $? 0 "reservation_policy=fail"

		isVM
		if [[ $? -eq 1 ]];then
			lszdev $DASD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag should only be available on z/VM"
		else
			lszdev $DASD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag=0"
		fi
		#change device driver configuration (#2)
		assert_exec 0 "chzdev $DASD cmb_enable=1"
		lszdev $DASD -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"
		isVM
		if [[ $? -ne 0 ]];then
			#detach device
			assert_exec 0 "chchp -c 0 $DASD_CHPID"
			assert_exec 0 "chchp -v 0 $DASD_CHPID"
			sleep 10
			#device offline and displayed as persistent online and active online?
			lszdev $DASD --online | grep $DASD
			assert_warn $? 0 "Active configuration online"

			lszdev $DASD --configured | grep $DASD
			assert_warn $? 0 "Persistent configuration online"

			zdev::isNoPathAvailable "${DASD}";
			assert_fail $? 0 "DASD $DASD path is offline"
			#re-atach device
			assert_exec 0 "chchp -c 1 $DASD_CHPID"
			assert_exec 0 "chchp -v 1 $DASD_CHPID"
			sleep 10
		else
                        assert_exec 0 "chzdev $DASD -a -d"
                        assert_exec 0 "chzdev $DASD -a -e"
                        sleep 10
                fi
		#device online and displayed as persistent online and active online?
		lsdasd | grep $DASD
		assert_fail $? 0 "DASD $DASD is online"

		lszdev $DASD --online | grep $DASD
		assert_warn $? 0 "Active configuration online"

		lszdev $DASD --configured | grep $DASD
		assert_warn $? 0 "Persistent configuration online"
		#device driver configuration (#2) ?

		#less strong condition: This doesn't work on internal driver because of the missing initrd
		lszdev dasd --type -i | grep eer_pages | grep 6
		assert_warn $? 0 "eer_pages=6"

		lszdev $DASD -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"
		#change device and device driver configuration (#3)
		assert_exec 0 "chzdev --type dasd -y --remove-all"
		assert_exec 0 "chzdev $DASD-$DASD -y --remove-all"

		#unload device drivers
		#device offline and displayed as persistent online and active online?
		#reload device drivers
		#device online and displayed as persistent online and active online?
		#device and device driver configuration (#3) ?
		#not possipble -> dasd root device

		#device persistent off
		assert_exec 0 "chzdev dasd $DASD -p -d"
		#device online and displayed as persistent offline and active online?
		lsdasd | grep $DASD
		assert_fail $? 0 "DASD $DASD is online"

		lszdev $DASD --online | grep $DASD
		assert_warn $? 0 "Active configuration online"

		lszdev $DASD --configured | grep $DASD
		assert_warn $? 1 "Persistent configuration offline"

		isVM
		if [[ $? -ne 0 ]];then
			#detach device
			assert_exec 0 "chchp -c 0 $DASD_CHPID"
			assert_exec 0 "chchp -v 0 $DASD_CHPID"
			sleep 10
			#device offline and displayed as persistent offline and active online?
			zdev::isNoPathAvailable "${DASD}";
			assert_fail $? 0 "DASD $DASD path is offline"

			lszdev $DASD --online | grep $DASD
			assert_warn $? 0 "Active configuration online"

			lszdev $DASD-$DASD --configured | grep $DASD
			assert_warn $? 1 "Persistent configuration offline"
			#re-attach device
			assert_exec 0 "chchp -c 1 $DASD_CHPID"
			assert_exec 0 "chchp -v 1 $DASD_CHPID"
			sleep 10
		else
                        assert_exec 0 "chzdev $DASD -a -d"
                        assert_exec 0 "chzdev $DASD -a -e"
                        sleep 10
                fi
		#load configuration
		assert_exec 0 "chzdev --import dasd.conf"
		#device online and displayed as persistent online and active online?
		lsdasd | grep $DASD
		assert_fail $? 0 "DASD $DASD is online"

		lszdev $DASD --online | grep $DASD
		assert_warn $? 0 "Active configuration online"

		lszdev $DASD --configured | grep $DASD
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $DASD -i | grep eer_enabled | awk '{print $2}' | grep 1
		assert_warn $? 0 "eer_enabled=1"

		lszdev $DASD -i | grep erplog | awk '{print $2}' | grep 1
		assert_warn $? 0 "erplog=1"

		lszdev dasd $DASD -i | grep expires | awk '{print $2}' | grep 31
		assert_warn $? 0 "expires=31"

		lszdev $DASD -i | grep failfast | awk '{print $2}' | grep 1
		assert_warn $? 0 "failfast=1"

		lszdev $DASD -i | grep readonly | awk '{print $2}' | grep 1
		assert_warn $? 0 "readonly=1"
		#depends on patch not yet in distro
		if [[ $? -eq 0 ]];then
			lszdev $DASD -i | grep timeout | awk '{print $2}' | grep 999
			assert_warn $? 0 "timeout=999"

			lszdev $DASD -i | grep retries | awk '{print $2}' | grep 999
			assert_warn $? 0 "retries=999"
		fi
		lszdev $DASD -i | grep reservation_policy | awk '{print $2}' | grep fail
		assert_warn $? 0 "reservation_policy=fail"

		isVM
		if [[ $? -eq 1 ]];then
			lszdev $DASD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag should only be available on z/VM"
		else
			lszdev $DASD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag=0"
		fi
end_section 0
clean
exit 0
