# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 30_DASD_ECKD.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f dasd-eckd.conf
	chzdev $DASD_ECKD cmb_enable=0 erplog=0 failfast=0 readonly=0 reservation_policy=ignore
	chzdev dasd-eckd --type -y --remove-all
	chzdev $DASD_ECKD -y --remove-all
	chzdev $DASD_ECKD -d
	chchp -v 0 $DASD_ECKD_CHPID
	chchp -c 0 $DASD_ECKD_CHPID
}

start_section 0 "30 DASD_ECKD test"

if grep -q 30_DASD_ECKD omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi

		chchp -v 1 $DASD_ECKD_CHPID
		chchp -c 1 $DASD_ECKD_CHPID
		sleep 10
		#device online and displayed as persistent online and active online?
		lsdasd | grep $DASD_ECKD
		assert_fail $? 0 "DASD_ECKD $DASD_ECKD is online"

		lszdev dasd-eckd $DASD_ECKD --online | grep $DASD_ECKD
		assert_warn $? 0 "Active configuration online"

		lszdev dasd-eckd $DASD_ECKD --configured | grep $DASD_ECKD
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev dasd-eckd $DASD_ECKD -i | grep eer_enabled | awk '{print $2}' | grep 1
		assert_warn $? 0 "eer_enabled=1"

		lszdev dasd-eckd $DASD_ECKD -i | grep erplog | awk '{print $2}' | grep 1
		assert_warn $? 0 "erplog=1"

		lszdev dasd-eckd $DASD_ECKD -i | grep expires | awk '{print $2}' | grep 31
		assert_warn $? 0 "expires=31"

		lszdev dasd-eckd $DASD_ECKD -i | grep failfast | awk '{print $2}' | grep 1
		assert_warn $? 0 "failfast=1"

		lszdev dasd-eckd $DASD_ECKD -i | grep readonly | awk '{print $2}' | grep 1
		assert_warn $? 0 "readonly=1"
		#depends on patch not yet in distro
		if [[ $? -eq 0 ]];then
			lszdev dasd-eckd $DASD_ECKD -i | grep timeout | awk '{print $2}' | grep 999
			assert_warn $? 0 "timeout=999"

			lszdev dasd-eckd $DASD_ECKD -i | grep retries | awk '{print $2}' | grep 999
			assert_warn $? 0 "retries=999"
		fi
		lszdev dasd-eckd $DASD_ECKD -i | grep reservation_policy | awk '{print $2}' | grep fail
		assert_warn $? 0 "reservation_policy=fail"

		isVM
		if [[ $? -eq 1 ]];then
			lszdev dasd-eckd $DASD_ECKD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag should only be available on z/VM"
		else
			lszdev dasd-eckd $DASD_ECKD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag=0"
		fi
		#change device driver configuration (#2)
		assert_exec 0 "chzdev dasd-eckd $DASD_ECKD cmb_enable=1"
		lszdev dasd-eckd $DASD_ECKD -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

		isVM
		if [[ $? -ne 0 ]];then
			#detach device
			assert_exec 0 "chchp -c 0 $DASD_ECKD_CHPID"
			assert_exec 0 "chchp -v 0 $DASD_ECKD_CHPID"
			sleep 10
			#device offline and displayed as persistent online and active online?
			lszdev dasd-eckd $DASD_ECKD --online | grep $DASD_ECKD
			assert_warn $? 0 "Active configuration online"

			lszdev dasd-eckd $DASD_ECKD --configured | grep $DASD_ECKD
			assert_warn $? 0 "Persistent configuration online"

			zdev::isNoPathAvailable $DASD_ECKD;
			assert_fail $? 0 "DASD_ECKD $DASD_ECKD path is offline"
			#re-atach device
			assert_exec 0 "chchp -c 1 $DASD_CHPID"
			assert_exec 0 "chchp -v 1 $DASD_CHPID"
			sleep 10
		else
                        assert_exec 0 "chzdev $DASD_ECKD -a -d"
                        assert_exec 0 "chzdev $DASD_ECKD -a -e"
                        sleep 10
                fi
		#device online and displayed as persistent online and active online?
		lsdasd | grep $DASD_ECKD
		assert_fail $? 0 "DASD_ECKD $DASD_ECKD is online"

		lszdev dasd-eckd $DASD_ECKD --online | grep $DASD_ECKD
		assert_warn $? 0 "Active configuration online"

		lszdev dasd-eckd $DASD_ECKD --configured | grep $DASD_ECKD
		assert_warn $? 0 "Persistent configuration online"
		#device driver configuration (#2) ?
		#depends on patch not yet in distro
		#lszdev dasd-eckd $DASD_ECKD -i | grep autodetect | awk '{print $2}' | grep 1
		#assert_warn $? 0 "autodetect=1"

		#lszdev dasd-eckd $DASD_ECKD -i | grep nopav | awk '{print $2}' | grep 1
		#assert_warn $? 0 "nopav=1"

		#lszdev dasd-eckd $DASD_ECKD -i | grep nofcx | awk '{print $2}' | grep 1
		#assert_warn $? 0 "nofcx=1"

		lszdev dasd-eckd $DASD_ECKD -i | grep cmb_enable | awk '{print $2}' | grep 1
		assert_warn $? 0 "cmb_enable=1"
		#change device and device driver configuration (#3)
		assert_exec 7 "chzdev --type dasd-eckd -y --remove-all"
		assert_exec 0 "chzdev dasd-eckd $DASD_ECKD-$DASD_ECKD -y --remove-all"

		#unload device drivers
		#device offline and displayed as persistent online and active online?
		#reload device drivers
		#device online and displayed as persistent online and active online?
		#device and device driver configuration (#3) ?
		#not possipble -> dasd root device (covered in manual test)

		#device persistent off
		assert_exec 0 "chzdev dasd-eckd $DASD_ECKD -p -d"
		#device online and displayed as persistent offline and active online?
		lsdasd | grep $DASD_ECKD
		assert_fail $? 0 "DASD_ECKD $DASD_ECKD is online"

		lszdev dasd-eckd $DASD_ECKD --online | grep $DASD_ECKD
		assert_warn $? 0 "Active configuration online"

		lszdev dasd-eckd $DASD_ECKD --configured | grep $DASD_ECKD
		assert_warn $? 1 "Persistent configuration offline"

		isVM
		if [[ $? -ne 0 ]];then
			#detach device
			assert_exec 0 "chchp -c 0 $DASD_ECKD_CHPID"
			assert_exec 0 "chchp -v 0 $DASD_ECKD_CHPID"
			sleep 10
			#device offline and displayed as persistent offline and active online?
			zdev::isNoPathAvailable $DASD_ECKD;
			assert_fail $? 0 "DASD_ECKD $DASD_ECKD path is offline"

			lszdev dasd-eckd $DASD_ECKD --online | grep $DASD_ECKD
			assert_warn $? 0 "Active configuration online"

			lszdev dasd-eckd $DASD_ECKD-$DASD_ECKD --configured | grep $DASD_ECKD
			assert_warn $? 1 "Persistent configuration offline"
			#re-attach device
			assert_exec 0 "chchp -c 1 $DASD_ECKD_CHPID"
			assert_exec 0 "chchp -v 1 $DASD_ECKD_CHPID"
			sleep 10
		else
                        assert_exec 0 "chzdev $DASD_ECKD -a -d"
                        assert_exec 0 "chzdev $DASD_ECKD -a -e"
                        sleep 10
                fi
		#load configuration
		assert_exec 0 "chzdev dasd-eckd --import dasd-eckd.conf"
		#device online and displayed as persistent online and active online?
		lsdasd | grep $DASD_ECKD
		assert_fail $? 0 "DASD_ECKD $DASD_ECKD is online"

		lszdev dasd-eckd $DASD_ECKD --online | grep $DASD_ECKD
		assert_warn $? 0 "Active configuration online"

		lszdev dasd-eckd $DASD_ECKD --configured | grep $DASD_ECKD
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev dasd-eckd $DASD_ECKD -i | grep eer_enabled | awk '{print $2}' | grep 1
		assert_warn $? 0 "eer_enabled=1"

		lszdev dasd-eckd $DASD_ECKD -i | grep erplog | awk '{print $2}' | grep 1
		assert_warn $? 0 "erplog=1"

		lszdev dasd-eckd $DASD_ECKD -i | grep expires | awk '{print $2}' | grep 31
		assert_warn $? 0 "expires=31"

		lszdev dasd-eckd $DASD_ECKD -i | grep failfast | awk '{print $2}' | grep 1
		assert_warn $? 0 "failfast=1"

		lszdev dasd-eckd $DASD_ECKD -i | grep readonly | awk '{print $2}' | grep 1
		assert_warn $? 0 "readonly=1"
		#depends on patch not yet in distro
		if [[ $? -eq 0 ]];then
			lszdev dasd-eckd $DASD_ECKD -i | grep timeout | awk '{print $2}' | grep 999
			assert_warn $? 0 "timeout=999"

			lszdev dasd-eckd $DASD_ECKD -i | grep retries | awk '{print $2}' | grep 999
			assert_warn $? 0 "retries=999"
		fi
		lszdev dasd-eckd $DASD_ECKD -i | grep reservation_policy | awk '{print $2}' | grep fail
		assert_warn $? 0 "reservation_policy=fail"

		isVM
		if [[ $? -eq 1 ]];then
			lszdev dasd-eckd $DASD_ECKD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag should only be available on z/VM"
		else
			lszdev dasd-eckd $DASD_ECKD -i | grep use_diag | awk '{print $2}' | grep 0
			assert_warn $? 0 "use_diag=0"
		fi

end_section 0
clean
exit 0
