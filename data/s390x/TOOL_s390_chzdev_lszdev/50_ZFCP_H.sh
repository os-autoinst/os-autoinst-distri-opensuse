# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 50_ZFCP_H.sh
# Description: ZFCP test of LS1303.
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f zfcp-h.conf
	chzdev zfcp --type queue_depth=32
	chzdev zfcp --type allow_lun_scan=1
	chzdev zfcp --type no_auto_port_rescan=0
	chzdev zfcp --type port_scan_ratelimit=60000
	chzdev zfcp --type port_scan_backoff=500
	chzdev zfcp --type --remove-all
	chzdev $ZFCP_H -y --remove-all
	chzdev $ZFCP_H -d
	chchp -v 0 $ZFCP_H_CHPID
	chchp -c 0 $ZFCP_H_CHPID
}

start_section 0 "50 ZFCP_H test"

if grep -q 50_ZFCP_H omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi

		chchp -v 1 $ZFCP_H_CHPID
		chchp -c 1 $ZFCP_H_CHPID
		sleep 10
		udevadm settle
		#device online and displayed as persistent online and active online?
		lszfcp -P | grep $ZFCP_H
		assert_fail $? 0 "ZFCP_H $ZFCP_H is online"

		lszdev $ZFCP_H --online | grep $ZFCP_H
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_H --configured | grep $ZFCP_H
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $ZFCP_H -i | grep cmb_enable | awk '{print $2}' | grep 0
		assert_warn $? 0 "cmb_enable=0"
		#change device driver configuration (#2)
		assert_exec 0 "chzdev $ZFCP_H -a -d"

		assert_exec 0 "chzdev $ZFCP_H --force cmb_enable=1"
		lszdev $ZFCP_H -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

		assert_exec 0 "chzdev $ZFCP_H -a -e"

		assert_exec 0 "chzdev zfcp --type queue_depth=33"
		lszdev zfcp --type -i | grep queue_depth | awk '{print $2}' | grep 33
		assert_warn $? 0 "queue_depth=33"

		assert_exec 0 "chzdev zfcp --type allow_lun_scan=0"
		lszdev zfcp --type -i | grep allow_lun_scan | awk '{print $2}' | grep 0
		assert_warn $? 0 "allow_lun_scan=0"

		assert_exec 0 "chzdev zfcp --type no_auto_port_rescan=1"
		lszdev zfcp --type -i | grep no_auto_port_rescan | awk '{print $2}' | grep 1
		assert_warn $? 0 "no_auto_port_rescan=1"

		assert_exec 0 "chzdev zfcp --type port_scan_ratelimit=60001"
		lszdev zfcp --type -i | grep port_scan_ratelimit | awk '{print $2}' | grep 60001
		assert_warn $? 0 "port_scan_ratelimit=60001"

		assert_exec 0 "chzdev zfcp --type port_scan_backoff=501"
		lszdev zfcp --type -i | grep port_scan_backoff | awk '{print $2}' | grep 501
		assert_warn $? 0 "port_scan_backoff=501"
		#detach device
				isVM
		if [[ $? -ne 0 ]];then
			assert_exec 0 "chchp -c 0 $ZFCP_H_CHPID"
			assert_exec 0 "chchp -v 0 $ZFCP_H_CHPID"
			sleep 10
			#device offline and displayed as persistent online and active offline?
			lszfcp -P | grep $ZFCP_H
			assert_fail $? 1 "ZFCP_H $ZFCP_H is offline"

			lszdev $ZFCP_H --online | grep $ZFCP_H
			assert_warn $? 0 "Active configuration online"

			lszdev $ZFCP_H --configured | grep $ZFCP_H
			assert_warn $? 0 "Persistent configuration online"

			#re-atach device
			assert_exec 0 "chchp -c 1 $ZFCP_H_CHPID"
			assert_exec 0 "chchp -v 1 $ZFCP_H_CHPID"
		else
                        assert_exec 0 "chzdev $ZFCP_H -a -d"
                        assert_exec 0 "chzdev $ZFCP_H -a -e"
                fi
		sleep 10
		udevadm settle
		#device online and displayed as persistent online and active online?
		assert_exec 0 "chzdev $ZFCP_H port_rescan=1 -a"
		sleep 10
		lszfcp -P | grep $ZFCP_H
		assert_fail $? 0 "ZFCP_H $ZFCP_H is online"

		lszdev $ZFCP_H --online | grep $ZFCP_H
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_H --configured | grep $ZFCP_H
		assert_warn $? 0 "Persistent configuration online"
		#device driver configuration (#2) ?
		lszdev zfcp --type -i | grep queue_depth | awk '{print $2}' | grep 33
		assert_warn $? 0 "queue_depth=33"

		lszdev zfcp --type -i | grep allow_lun_scan | awk '{print $2}' | grep 0
		assert_warn $? 0 "allow_lun_scan=0"

		lszdev zfcp --type -i | grep no_auto_port_rescan | awk '{print $2}' | grep 1
		assert_warn $? 0 "no_auto_port_rescan=1"

		lszdev zfcp --type -i | grep port_scan_ratelimit | awk '{print $2}' | grep 60001
		assert_warn $? 0 "port_scan_ratelimit=60001"

		lszdev zfcp --type -i | grep port_scan_backoff | awk '{print $2}' | grep 501
		assert_warn $? 0 "port_scan_backoff=501"

		lszdev $ZFCP_H -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

		#change device and device driver configuration (#3)
		assert_exec 0 "chzdev $ZFCP_H -y --remove-all"
		assert_exec 0 "chzdev zfcp --type -y --remove-all"

    lsmod | grep -q zfcp
		if [[ $? -eq 0 ]];then
			#unload device drivers
			echo 'install zfcp /bin/false' > /etc/modprobe.d/blacklist.conf
      assert_exec 0 "modprobe -r -f zfcp"
			sleep 10
			#device offline and displayed as persistent online and active offline?
			lszfcp -P | grep $ZFCP_H
			assert_fail $? 1 "ZFCP_H $ZFCP_H is offline"

			lszdev $ZFCP_H --online | grep $ZFCP_H
			assert_warn $? 1 "Active configuration offline"

			lszdev $ZFCP_H --configured | grep $ZFCP_H
			assert_warn $? 0 "Persistent configuration online"
			#reload device drivers
			echo '' > /etc/modprobe.d/blacklist.conf
			#Config #3 while offline
			assert_exec 0 "chzdev zfcp --type datarouter=0 dbflevel=5"
			lszdev zfcp --type -i | grep dbflevel | awk '{print $2}' | grep 5
			assert_warn $? 0 "dbflevel=5"
			lszdev zfcp --type -i | grep datarouter | awk '{print $2}' | grep 0
			assert_warn $? 0 "datarouter=0"

			assert_exec 0 "modprobe zfcp"
			sleep 10
		else
			assert_exec 0 "chzdev $ZFCP_H -d"
			#Config #3 while offline
			assert_exec 0 "chzdev zfcp --type datarouter=0 dbflevel=5 -p"
			lszdev zfcp --type -i | grep dbflevel | grep 5
			assert_warn $? 0 "dbflevel=5"
			lszdev zfcp --type -i | grep datarouter | grep 0
			assert_warn $? 0 "datarouter=0"
			assert_exec 0 "chzdev $ZFCP_H -e"
			sleep 10
		fi

		#device online and displayed as persistent online and active online?
		assert_exec 0 "chzdev $ZFCP_H port_rescan=1 -a"

		lszfcp -P | grep $ZFCP_H
		assert_fail $? 0 "ZFCP_H $ZFCP_H is online"

		lszdev $ZFCP_H --online | grep $ZFCP_H
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_H --configured | grep $ZFCP_H
		assert_warn $? 0 "Persistent configuration online"

		#device and device driver configuration (#3) ?
		lszdev zfcp --type -i | grep dbflevel | grep 5
		assert_warn $? 0 "dbflevel=5"

		lszdev zfcp --type -i | grep datarouter | grep 0
		assert_warn $? 0 "datarouter=0"

		lszdev $ZFCP_H -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

        #device persistent off
		assert_exec 0 "chzdev zfcp $ZFCP_H -p -d"
		#device online and displayed as persistent offline and active online?
		lszfcp -P | grep $ZFCP_H
		assert_fail $? 0 "ZFCP_H $ZFCP_H is online"

		lszdev $ZFCP_H --online | grep $ZFCP_H
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_H --configured | grep $ZFCP_H
		assert_warn $? 1 "Persistent configuration offline"

		isVM
		if [[ $? -ne 0 ]];then
			#detach device
			assert_exec 0 "chchp -c 0 $ZFCP_H_CHPID"
			assert_exec 0 "chchp -v 0 $ZFCP_H_CHPID"
			sleep 10
			#device offline and displayed as persistent offline and active online?
			lszfcp -P | grep $ZFCP_H
			assert_fail $? 1 "ZFCP_H $ZFCP_H is offline"

			lszdev $ZFCP_H --online | grep $ZFCP_H
			assert_warn $? 0 "Active configuration online"

			lszdev $ZFCP_H --configured | grep $ZFCP_H
			assert_warn $? 1 "Persistent configuration offline"
			#re-attach device
			assert_exec 0 "chchp -c 1 $ZFCP_H_CHPID"
			assert_exec 0 "chchp -v 1 $ZFCP_H_CHPID"
		else
                        assert_exec 0 "chzdev $ZFCP_H -a -d"
                        assert_exec 0 "chzdev $ZFCP_H -a -e"
                fi
		sleep 10
		udevadm settle
		#load configuration
		assert_exec 0 "chzdev --import zfcp-h.conf"
		#device online and displayed as persistent online and active online?
		lszfcp -P | grep $ZFCP_H
		assert_fail $? 0 "ZFCP_H $ZFCP_H is online"

		lszdev $ZFCP_H --online | grep $ZFCP_H
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_H --configured | grep $ZFCP_H
		assert_warn $? 0 "Persistent configuration online"

end_section 0

clean
exit 0
