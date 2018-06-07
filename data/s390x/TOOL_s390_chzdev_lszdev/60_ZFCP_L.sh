# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 60_ZFCP_L.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f zfcp-l.conf
	chzdev zfcp --type queue_depth=32
	chzdev zfcp --type allow_lun_scan=1
	chzdev zfcp --type no_auto_port_rescan=0
	chzdev zfcp --type port_scan_ratelimit=60000
	chzdev zfcp --type port_scan_backoff=500
	chzdev zfcp --type --remove-all
	chzdev $ZFCP_L -y --remove-all
	chzdev $ZFCP_L -d
	chzdev $ZFCP_L_H -y --remove-all
	chzdev $ZFCP_L_H -d
	chchp -v 0 $ZFCP_L_CHPID
	chchp -c 0 $ZFCP_L_CHPID
}

start_section 0 "60 ZFCP_L test"

if grep -q 60_ZFCP_L omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi

		chchp -v 1 $ZFCP_L_CHPID
		chchp -c 1 $ZFCP_L_CHPID
		LUN="$( cut -d ':' -f 3 <<< "$ZFCP_L" )";
		sleep 10
		#device online and displayed as persistent online and active online?
		lsluns -a | grep $LUN
		assert_fail $? 0 "ZFCP_L $ZFCP_L is online"

		lszdev $ZFCP_L --online | grep $ZFCP_L
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_L --configured | grep $ZFCP_L
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $ZFCP_L -i | grep queue_depth | awk '{print $2}' | grep 33
		assert_warn $? 0 "scsi_dev/queue_depth=33"

		lszdev $ZFCP_L -i | grep timeout | awk '{print $2}' | grep 33
		assert_warn $? 0 "scsi_dev/timeout=33"
		#change device driver configuration (#2)

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
			assert_exec 0 "chchp -c 0 $ZFCP_L_CHPID"
			assert_exec 0 "chchp -v 0 $ZFCP_L_CHPID"
			sleep 10
			#device offline and displayed as persistent online and active offline?

			lsluns -a | grep $LUN | grep offline
			assert_fail $? 0 "ZFCP_L $ZFCP_L is offline"
			lszdev $ZFCP_L --online | grep $ZFCP_L
			assert_warn $? 0 "Active configuration online"

			lszdev $ZFCP_L --configured | grep $ZFCP_L
			assert_warn $? 0 "Persistent configuration online"
			#re-atach device
			assert_exec 0 "chchp -c 1 $ZFCP_L_CHPID"
			assert_exec 0 "chchp -v 1 $ZFCP_L_CHPID"
		else
                        assert_exec 0 "chzdev $ZFCP_L -a -d"
                        assert_exec 0 "chzdev $ZFCP_L -a -e"
                fi
		sleep 10
		#device online and displayed as persistent online and active online?
		assert_exec 0 "chzdev $ZFCP_L_H port_rescan=1 -a"
		sleep 10
		lsluns -a | grep $LUN
		assert_fail $? 0 "ZFCP_L $ZFCP_L is online"

		lszdev $ZFCP_L --online | grep $ZFCP_L
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_L --configured | grep $ZFCP_L
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
		#change device and device driver configuration (#3)
		assert_exec 0 "chzdev $ZFCP_L -y --remove-all"
		assert_exec 0 "chzdev zfcp --type -y --remove-all"
		sleep 10

        assert_exec 0 "lsmod | grep -q zfcp"

		if [[ $? -ne 0 ]];then
			#unload device drivers
			echo 'install zfcp /bin/false' > /etc/modprobe.d/blacklist.conf
			assert_exec 0 "modprobe -r zfcp"
			#device offline and displayed as persistent online and active offline?
			sleep 15
			lsluns -a | grep $LUN
			assert_fail $? 1 "ZFCP_L $ZFCP_L is offline"

			lszdev $ZFCP_L --online | grep $ZFCP_L
			assert_warn $? 1 "Active configuration offline"

			lszdev $ZFCP_L --configured | grep $ZFCP_L
			assert_warn $? 0 "Persistent configuration online"
			#reload device drivers
			echo '' > /etc/modprobe.d/blacklist.conf
			#Config #3 while device offline
			assert_exec 0 "chzdev zfcp --type dbflevel=5 datarouter=0"
			lszdev zfcp --type -i | grep dbflevel | awk '{print $2}' | grep 5
			assert_warn $? 0 "dbflevel=5"
			lszdev zfcp --type -i | grep datarouter | awk '{print $2}' | grep 0
			assert_warn $? 0 "datarouter=0"

			assert_exec 0 "modprobe zfcp"
			sleep 15
		else
			assert_exec 0 "chzdev $ZFCP_L -a -d"
			#Config #3 while offline
			assert_exec 0 "chzdev zfcp --type datarouter=0 dbflevel=5 -p"
			lszdev zfcp --type -i | grep dbflevel | grep 5
			assert_warn $? 0 "dbflevel=5"
			lszdev zfcp --type -i | grep datarouter | grep 0
			assert_warn $? 0 "datarouter=0"
			assert_exec 0 "chzdev $ZFCP_L -a -e"
			sleep 10
		fi
		#device online and displayed as persistent online and active online?
		assert_exec 0 "chzdev $ZFCP_L_H port_rescan=1 -a"
		sleep 10
		lsluns -a | grep $LUN
		assert_fail $? 0 "ZFCP_L $ZFCP_L is online"

		lszdev $ZFCP_L --online | grep $ZFCP_L
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_L --configured | grep $ZFCP_L
		assert_warn $? 0 "Persistent configuration online"

		#device and device driver configuration (#3) ?

		#device persistent off
		sleep 10
		assert_exec 0 "chzdev zfcp $ZFCP_L -p -d"
		sleep 10
		#device online and displayed as persistent offline and active online?
		lsluns -a | grep $LUN
		assert_fail $? 0 "ZFCP_L $ZFCP_L is online"

		lszdev $ZFCP_L --online | grep $ZFCP_L
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_L --configured | grep $ZFCP_L
		assert_warn $? 1 "Persistent configuration offline"
		#detach device
		isVM
		if [[ $? -ne 0 ]];then
			assert_exec 0 "chchp -c 0 $ZFCP_L_CHPID"
			assert_exec 0 "chchp -v 0 $ZFCP_L_CHPID"
			sleep 10
			#device offline and displayed as persistent offline and active online?
			lsluns -a | grep $LUN | grep offline
			assert_fail $? 0 "ZFCP_L $ZFCP_L is offline"

			lszdev $ZFCP_L --online | grep $ZFCP_L
			assert_warn $? 0 "Active configuration online"

			lszdev $ZFCP_L --configured | grep $ZFCP_L
			assert_warn $? 1 "Persistent configuration offline"
			#re-attach device
			assert_exec 0 "chchp -c 1 $ZFCP_L_CHPID"
			assert_exec 0 "chchp -v 1 $ZFCP_L_CHPID"
		else
                        assert_exec 0 "chzdev $ZFCP_L -a -d"
                        assert_exec 0 "chzdev $ZFCP_L -a -e"
                fi
		sleep 10
		#load configuration
		assert_exec 0 "chzdev --import zfcp-l.conf"
		#device online and displayed as persistent online and active online?
		lsluns -a | grep $LUN
		assert_fail $? 0 "ZFCP_L $ZFCP_L is online"

		lszdev $ZFCP_L --online | grep $ZFCP_L
		assert_warn $? 0 "Active configuration online"

		lszdev $ZFCP_L --configured | grep $ZFCP_L
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $ZFCP_L -i | grep queue_depth | awk '{print $2}' | grep 33
		assert_warn $? 0 "scsi_dev/queue_depth=33"

		lszdev $ZFCP_L -i | grep timeout | awk '{print $2}' | grep 33
		assert_warn $? 0 "scsi_dev/timeout=33"
end_section 0

clean

exit 0
