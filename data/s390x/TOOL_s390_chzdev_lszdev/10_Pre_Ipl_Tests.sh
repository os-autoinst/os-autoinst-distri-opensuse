# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 10_Pre_Ipl_Tests.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

for word in "$@"; do
	echo "adding $word to list of omitted tests"
	echo "$word" >> omit;
done

start_section 0 "10 Pre Ipl Tests and Preperation"

	start_section 1 "10.0 Activate chpids"

		isVM
		if [[ $? -eq 0 ]];then
			#chipds on in z/vm
			allchpids="$DASD_CHPID $DASD_ECKD_CHPID $DASD_FBA_CHPID $ZFCP_H_CHPID $ZFCP_L_CHPID $ZFCP_HOST_CHPID $ZFCP_LUN_CHPID $QETH_CHPID $CTC_CHPID $LCS_CHPID"
			chpidlist=($allchpids)

			for singlechpid in "${chpidlist[@]}"
			do
			    vmcp vary on chpid $singlechpid
			done

			#attach devices in z/vm
			hostname=`hostname`

			#cut ssid
			vmcp att ${DASD: -4} to $hostname
			vmcp att ${DASD_ECKD: -4} to $hostname
			vmcp att ${DASD_FBA: -4} to $hostname
			vmcp att ${ZFCP_H: -4} to $hostname
			vmcp att ${ZFCP_HOST: -4} to $hostname

			#cut ssid ,wwpn and lun
			IFS=':' read -ra ZFCP_L_DEV <<< "$ZFCP_L"
			for l_dev in "${ZFCP_L_DEV[@]}"; do
			    vmcp att ${l_dev: -4} to $hostname
			    break
			done

			#cut ssid ,wwpn and lun
			IFS=':' read -ra ZFCP_LUN_DEV <<< "$ZFCP_LUN"
			for lun_dev in "${ZFCP_LUN_DEV[@]}"; do
			    vmcp att ${lun_dev: -4} to $hostname
			    break
			done

			#split into 3 devices
			IFS=':' read -ra QETHLIST <<< "$QETH"
			for singleqeth in "${QETHLIST[@]}"; do
			    vmcp att ${singleqeth: -4} to $hostname
			done
		fi

		assert_exec 0 "chchp -v 1 $DASD_CHPID $DASD_ECKD_CHPID $DASD_FBA_CHPID $ZFCP_H_CHPID $ZFCP_L_CHPID $ZFCP_HOST_CHPID $ZFCP_LUN_CHPID $QETH_CHPID $CTC_CHPID $LCS_CHPID"
		assert_exec 0 "chchp -c 1 $DASD_CHPID $DASD_ECKD_CHPID $DASD_FBA_CHPID $ZFCP_H_CHPID $ZFCP_L_CHPID $ZFCP_HOST_CHPID $ZFCP_LUN_CHPID $QETH_CHPID $CTC_CHPID $LCS_CHPID"
	end_section 1

	start_section 1 "10.1 Pre Ipl dasd"

		if grep -q 20_DASD omit; then
			assert_exec 0 "echo 'omitting 20_DASD'"
		else
			#device offline and displayed as persistent offline and active offline?
			lszdev $DASD --online | grep $DASD
			assert_warn $? 1 "Active configuration offline"

			lszdev $DASD --configured | grep $DASD
			assert_warn $? 1 "Persistent configuration offline"

			lsdasd | grep $DASD
			assert_fail $? 1 "DASD $DASD is offline"

			#enable device persistent/active
			assert_exec 0 "chzdev dasd $DASD -e -V"
			#device online and displayed as persistent online and active online?
			lsdasd | grep $DASD
			assert_fail $? 0 "DASD $DASD is online"

			lszdev $DASD --online | grep $DASD
			assert_warn $? 0 "Active configuration online"

			lszdev $DASD --configured | grep $DASD
			assert_warn $? 0 "Persistent configuration online"
			#change device configuration (#1)
			assert_exec 0 "chzdev $DASD eer_enabled=1"
			lszdev $DASD -i | grep eer_enabled | grep 1
			assert_warn $? 0 "eer_enabled=1"

			assert_exec 0 "chzdev $DASD erplog=1"
			lszdev $DASD -i | grep erplog | grep 1
			assert_warn $? 0 "erplog=1"

			assert_exec 0 "chzdev $DASD expires=31"
			lszdev $DASD -i | grep expires | grep 31
			assert_warn $? 0 "expires=31"

			assert_exec 0 "chzdev $DASD failfast=1"
			lszdev $DASD -i | grep failfast | grep 1
			assert_warn $? 0 "failfast=1"

			assert_exec 0 "chzdev $DASD readonly=1"
			lszdev $DASD -i | grep readonly | grep 1
			assert_warn $? 0 "readonly=1"
			#depends on patch not yet in distro

            assert_exec 0 "chzdev $DASD timeout=999"
			lszdev $DASD -i | grep timeout | grep 999
			assert_warn $? 0 "timeout=999"

			assert_exec 0 "chzdev $DASD retries=999"
			lszdev $DASD -i | grep retries | grep 999
			assert_warn $? 0 "retries=999"

			assert_exec 0 "chzdev $DASD reservation_policy=fail"
			lszdev $DASD -i | grep reservation_policy | grep fail
			assert_warn $? 0 "reservation_policy"
			#save configuration
			assert_exec 0 "chzdev $DASD --export dasd.conf"

			#device active off
			assert_exec 0 "chzdev $DASD -d -a -V"
			#more configuration which only works if device is offline
			isVM
			if [[ $? -eq 1 ]];then
				chzdev $DASD use_diag=1
				assert_warn $? 9 "use_diag should only be available on z/VM"
				else
				assert_exec 0 "chzdev $DASD use_diag=1"
				lszdev $DASD -i | grep use_diag | awk '{print $2}' | grep 1
				assert_warn $? 0 "use_diag=1"
				#cant be set online while usediag=1
				assert_exec 0 "chzdev $DASD use_diag=0"
				lszdev $DASD -i | grep use_diag | awk '{print $2}' | grep 0
				assert_warn $? 0 "use_diag=0"
			fi
			#device offline and displayed as persistent online and active offline?
			lsdasd | grep $DASD
			assert_fail $? 1 "DASD $DASD is offline"

			lszdev $DASD --online | grep $DASD
			assert_warn $? 1 "Active configuration offline"

			lszdev $DASD --configured | grep $DASD
			assert_warn $? 0 "Persistent configuration online"
			#apply persistent configuration
			assert_exec 0 "chzdev $DASD --apply"
			#device online and displayed as persistent online and active online?
			lsdasd | grep $DASD
			assert_fail $? 0 "DASD $DASD is online"

			lszdev $DASD --online | grep $DASD
			assert_warn $? 0 "Active configuration online"

			lszdev $DASD --configured | grep $DASD
			assert_warn $? 0 "Persistent configuration online"
		fi
	end_section 1

	start_section 1 "10.2 Pre Ipl dasd eckd"

		if grep -q 30_DASD_ECKD omit; then
			assert_exec 0 "echo 'omitting 30_DASD_ECKD'"
		else
			#device offline and displayed as persistent offline and active offline?
			lszdev $DASD_ECKD --online | grep $DASD_ECKD
			assert_warn $? 1 "Active configuration offline"

			lszdev $DASD_ECKD --configured | grep $DASD_ECKD
			assert_warn $? 1 "Persistent configuration offline"

			lsdasd | grep $DASD_ECKD
			assert_fail $? 1 "DASD_ECKD $DASD_ECKD is offline"

			#enable device persistent/active
			assert_exec 0 "chzdev dasd-eckd $DASD_ECKD -e -V"
			#device online and displayed as persistent online and active online?
			lsdasd | grep $DASD_ECKD
			assert_fail $? 0 "DASD_ECKD $DASD_ECKD is online"

			lszdev $DASD_ECKD --online | grep $DASD_ECKD
			assert_warn $? 0 "Active configuration online"

			lszdev $DASD_ECKD --configured | grep $DASD_ECKD
			assert_warn $? 0 "Persistent configuration online"
			#change device configuration (#1)
			assert_exec 0 "chzdev $DASD_ECKD eer_enabled=1"
			lszdev $DASD_ECKD -i | grep eer_enabled | grep 1
			assert_warn $? 0 "eer_enabled=1"

			assert_exec 0 "chzdev $DASD_ECKD erplog=1"
			lszdev $DASD_ECKD -i | grep erplog | grep 1
			assert_warn $? 0 "erplog=1"

			assert_exec 0 "chzdev $DASD_ECKD expires=31"
			lszdev $DASD_ECKD -i | grep expires | grep 31
			assert_warn $? 0 "expires=31"

			assert_exec 0 "chzdev $DASD_ECKD failfast=1"
			lszdev $DASD_ECKD -i | grep failfast | grep 1
			assert_warn $? 0 "failfast=1"

			assert_exec 0 "chzdev $DASD_ECKD readonly=1"
			lszdev $DASD_ECKD -i | grep readonly | grep 1
			assert_warn $? 0 "readonly=1"
			#depends on patch not yet in distro
			if [[ $? -eq 0 ]];then
				assert_exec 0 "chzdev $DASD_ECKD timeout=999"
				lszdev $DASD_ECKD -i | grep timeout | grep 999
				assert_warn $? 0 "timeout=999"

				assert_exec 0 "chzdev $DASD_ECKD retries=999"
				lszdev $DASD_ECKD -i | grep retries | grep 999
				assert_warn $? 0 "retries=999"
			fi
			assert_exec 0 "chzdev $DASD_ECKD reservation_policy=fail"
			lszdev $DASD_ECKD -i | grep reservation_policy | grep fail
			assert_warn $? 0 "reservation_policy"
			#save configuration
			assert_exec 0 "chzdev $DASD_ECKD --export dasd-eckd.conf"

			#device active off
			assert_exec 0 "chzdev $DASD_ECKD -d -a -V"
			#more configuration which only works if device is offline
			isVM
			if [[ $? -eq 1 ]];then
				chzdev $DASD_ECKD use_diag=1
				assert_warn $? 9 "use_diag should only be available on z/VM"
				else
				assert_exec 0 "chzdev $DASD_ECKD use_diag=1"
				lszdev $DASD_ECKD -i | grep use_diag | grep 1
				assert_warn $? 0 "use_diag=1"
				#cant be set online while usediag=1
				assert_exec 0 "chzdev $DASD_ECKD use_diag=0"
				lszdev $DASD_ECKD -i | grep use_diag | awk '{print $2}' | grep 0
				assert_warn $? 0 "use_diag=0"
			fi
			#device offline and displayed as persistent online and active offline?
			lsdasd | grep $DASD_ECKD
			assert_fail $? 1 "DASD_ECKD $DASD_ECKD is offline"

			lszdev $DASD_ECKD --online | grep $DASD_ECKD
			assert_warn $? 1 "Active configuration offline"

			lszdev $DASD_ECKD --configured | grep $DASD_ECKD
			assert_warn $? 0 "Persistent configuration online"
			#apply persistent configuration
			assert_exec 0 "chzdev $DASD_ECKD --apply"
			#device online and displayed as persistent online and active online?
			lsdasd | grep $DASD_ECKD
			assert_fail $? 0 "DASD_ECKD $DASD_ECKD is online"

			lszdev $DASD_ECKD --online | grep $DASD_ECKD
			assert_warn $? 0 "Active configuration online"

			lszdev $DASD_ECKD --configured | grep $DASD_ECKD
			assert_warn $? 0 "Persistent configuration online"
		fi
	end_section 1

	./10_Pre_Ipl_Tests_1.sh
	./10_Pre_Ipl_Tests_2.sh
	./10_Pre_Ipl_Tests_3.sh

	#add cio_ignore to zipl.conf, this should not have any effect, the created udev rules should make the devices available after reipl
	cio_ignore -a $DASD
	cio_ignore -a $DASD_ECKD
	cio_ignore -a $DASD_FBA
	cio_ignore -a $ZFCP_H
	cio_ignore -a $ZFCP_L_H
	cio_ignore -a $ZFCP_HOST
	cio_ignore -a $ZFCP_LUN_H
	cio_ignore -a $ENCCW
	cio_ignore -a $CTC_IN
	cio_ignore -a $LCS_IN
	cio_ignore -a $GCCW


end_section 0
exit 0
