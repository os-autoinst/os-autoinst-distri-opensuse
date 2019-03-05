# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 70_ZFCP_HOST.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f zfcp-host.conf
	chzdev zfcp-host --type queue_depth=32
	chzdev zfcp-host --type allow_lun_scan=1
	chzdev zfcp-host --type no_auto_port_rescan=0
	chzdev zfcp-host --type port_scan_ratelimit=60000
	chzdev zfcp-host --type port_scan_backoff=500
	chzdev zfcp-host --type --remove-all
	chzdev zfcp-host $ZFCP_HOST -y --remove-all
	chzdev zfcp-host $ZFCP_HOST -d
	chchp -v 0 $ZFCP_HOST_CHPID
	chchp -c 0 $ZFCP_HOST_CHPID
}

start_section 0 "70 ZFCP_HOST test"

if grep -q 70_ZFCP_HOST omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi

		chchp -v 1 $ZFCP_HOST_CHPID
		chchp -c 1 $ZFCP_HOST_CHPID
		sleep 10
		udevadm settle
		#device online and displayed as persistent online and active online?
		lszfcp -P | grep $ZFCP_HOST
		assert_fail $? 0 "ZFCP_HOST $ZFCP_HOST is online"

		lszdev zfcp-host $ZFCP_HOST --online | grep $ZFCP_HOST
		assert_warn $? 0 "Active configuration online"

		lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $ZFCP_HOST -i | grep cmb_enable | awk '{print $2}' | grep 0
		assert_warn $? 0 "cmb_enable=0"
		#change device driver configuration (#2)
		assert_exec 0 "chzdev $ZFCP_HOST -a -d"

		assert_exec 0 "chzdev $ZFCP_HOST --force cmb_enable=1"
		lszdev $ZFCP_HOST -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

		assert_exec 0 "chzdev $ZFCP_HOST -a -e"

		assert_exec 0 "chzdev zfcp --type queue_depth=33"
		lszdev zfcp-host --type -i | grep queue_depth | awk '{print $2}' | grep 33
		assert_warn $? 0 "queue_depth=33"

		assert_exec 0 "chzdev zfcp --type allow_lun_scan=0"
		lszdev zfcp-host --type -i | grep allow_lun_scan | awk '{print $2}' | grep 0
		assert_warn $? 0 "allow_lun_scan=0"

		assert_exec 0 "chzdev zfcp --type no_auto_port_rescan=1"
		lszdev zfcp-host --type -i | grep no_auto_port_rescan | awk '{print $2}' | grep 1
		assert_warn $? 0 "no_auto_port_rescan=1"

		assert_exec 0 "chzdev zfcp --type port_scan_ratelimit=60001"
		lszdev zfcp-host --type -i | grep port_scan_ratelimit | awk '{print $2}' | grep 60001
		assert_warn $? 0 "port_scan_ratelimit=60001"

		assert_exec 0 "chzdev zfcp --type port_scan_backoff=501"
		lszdev zfcp-host --type -i | grep port_scan_backoff | awk '{print $2}' | grep 501
		assert_warn $? 0 "port_scan_backoff=501"

		#detach device
		isVM
		if [[ $? -ne 0 ]];then
			assert_exec 0 "chchp -c 0 $ZFCP_HOST_CHPID"
			assert_exec 0 "chchp -v 0 $ZFCP_HOST_CHPID"
			sleep 10
			#device offline and displayed as persistent online and active offline?
			lszfcp -P | grep $ZFCP_HOST
			assert_fail $? 1 "ZFCP_HOST $ZFCP_HOST is offline"

			lszdev $ZFCP_HOST --online | grep $ZFCP_HOST
			assert_warn $? 0 "Active configuration online"

			lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
			assert_warn $? 0 "Persistent configuration online"

			#re-atach device
			assert_exec 0 "chchp -c 1 $ZFCP_HOST_CHPID"
			assert_exec 0 "chchp -v 1 $ZFCP_HOST_CHPID"
		else
                        assert_exec 0 "chzdev $ZFCP_HOST -a -d"
                        assert_exec 0 "chzdev $ZFCP_HOST -a -e"
                fi
		sleep 10
		udevadm settle
		#device online and displayed as persistent online and active online?
		assert_exec 0 "chzdev $ZFCP_HOST port_rescan=1 -a"
		sleep 10
		lszfcp -P | grep $ZFCP_HOST
		assert_fail $? 0 "ZFCP_HOST $ZFCP_HOST is online"

		lszdev zfcp-host $ZFCP_HOST --online | grep $ZFCP_HOST
		assert_warn $? 0 "Active configuration online"

		lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
		assert_warn $? 0 "Persistent configuration online"
		#device driver configuration (#2) ?
		lszdev zfcp-host --type -i | grep queue_depth | awk '{print $2}' | grep 33
		assert_warn $? 0 "queue_depth=33"

		lszdev zfcp-host --type -i | grep allow_lun_scan | awk '{print $2}' | grep 0
		assert_warn $? 0 "allow_lun_scan=0"

		lszdev zfcp-host --type -i | grep no_auto_port_rescan | awk '{print $2}' | grep 1
		assert_warn $? 0 "no_auto_port_rescan=1"

		lszdev zfcp-host --type -i | grep port_scan_ratelimit | awk '{print $2}' | grep 60001
		assert_warn $? 0 "port_scan_ratelimit=60001"

		lszdev zfcp-host --type -i | grep port_scan_backoff | awk '{print $2}' | grep 501
		assert_warn $? 0 "port_scan_backoff=501"

		lszdev $ZFCP_HOST -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

		#change device and device driver configuration (#3)
		assert_exec 0 "chzdev zfcp-host $ZFCP_HOST -y --remove-all"
		assert_exec 0 "chzdev zfcp-host --type -y --remove-all"

		lsmod | grep -q zfcp
    if [[ $? -eq 0 ]];then
			#unload device drivers
			echo 'install zfcp /bin/false' > /etc/modprobe.d/blacklist.conf
			assert_exec 0 "modprobe -r -f zfcp"
			sleep 10
			#device offline and displayed as persistent online and active offline?
			lszfcp -P | grep $ZFCP_HOST
			assert_fail $? 1 "ZFCP_HOST $ZFCP_HOST is offline"

			lszdev zfcp-host $ZFCP_HOST --online | grep $ZFCP_HOST
			assert_warn $? 1 "Active configuration offline"

			lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
			assert_warn $? 0 "Persistent configuration online"
			#reload device drivers
			echo '' > /etc/modprobe.d/blacklist.conf
			#Config #3 while device offline
			assert_exec 0 "chzdev zfcp-host --type dbflevel=5 datarouter=0"
			lszdev zfcp-host --type -i | grep dbflevel | awk '{print $2}' | grep 5
			assert_warn $? 0 "dbflevel=5"
			lszdev zfcp-host --type -i | grep datarouter | awk '{print $2}' | grep 0
			assert_warn $? 0 "datarouter=0"

			assert_exec 0 "modprobe zfcp"
			sleep 10
		else
			assert_exec 0 "chzdev $ZFCP_HOST -d"
			#Config #3 while offline
			assert_exec 0 "chzdev zfcp-host --type datarouter=0 dbflevel=5 -p"
			lszdev zfcp-host --type -i | grep dbflevel | grep 5
			assert_warn $? 0 "dbflevel=5"
			lszdev zfcp-host --type -i | grep datarouter | grep 0
			assert_warn $? 0 "datarouter=0"
			assert_exec 0 "chzdev $ZFCP_HOST -e"
			sleep 10
		fi

		#device online and displayed as persistent online and active online?
		assert_exec 0 "chzdev $ZFCP_HOST port_rescan=1 -a"

		lszfcp -P | grep $ZFCP_HOST
		assert_fail $? 0 "ZFCP_HOST $ZFCP_HOST is online"

		lszdev zfcp-host $ZFCP_HOST --online | grep $ZFCP_HOST
		assert_warn $? 0 "Active configuration online"

		lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
		assert_warn $? 0 "Persistent configuration online"

		#device and device driver configuration (#3) ?
		lszdev zfcp --type -i | grep dbflevel | grep 5
		assert_warn $? 0 "dbflevel=5"

		lszdev zfcp --type -i | grep datarouter | grep 0
		assert_warn $? 0 "datarouter=0"

		lszdev zfcp-host $ZFCP_HOST -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

        #device persistent off
		assert_exec 0 "chzdev zfcp-host $ZFCP_HOST -p -d"
		#device online and displayed as persistent offline and active online?
		lszfcp -P | grep $ZFCP_HOST
		assert_fail $? 0 "ZFCP_HOST $ZFCP_HOST is online"

		lszdev zfcp-host $ZFCP_HOST --online | grep $ZFCP_HOST
		assert_warn $? 0 "Active configuration online"

		lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
		assert_warn $? 1 "Persistent configuration offline"
		#detach device
		isVM
		if [[ $? -ne 0 ]];then
			assert_exec 0 "chchp -c 0 $ZFCP_HOST_CHPID"
			assert_exec 0 "chchp -v 0 $ZFCP_HOST_CHPID"
			sleep 10
			#device offline and displayed as persistent offline and active online?
			lszfcp -P | grep $ZFCP_HOST
			assert_fail $? 1 "ZFCP_HOST $ZFCP_HOST is offline"

			lszdev zfcp-host $ZFCP_HOST --online | grep $ZFCP_HOST
			assert_warn $? 0 "Active configuration online"

			lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
			assert_warn $? 1 "Persistent configuration offline"
			#re-attach device
			assert_exec 0 "chchp -c 1 $ZFCP_HOST_CHPID"
			assert_exec 0 "chchp -v 1 $ZFCP_HOST_CHPID"
		else
                        assert_exec 0 "chzdev $ZFCP_HOST -a -d"
                        assert_exec 0 "chzdev $ZFCP_HOST -a -e"
                fi
		sleep 10
		udevadm settle
		#load configuration
		assert_exec 0 "chzdev zfcp-host --import zfcp-host.conf"
		#device online and displayed as persistent online and active online?
		lszfcp -P | grep $ZFCP_HOST
		assert_fail $? 0 "ZFCP_HOST $ZFCP_HOST is online"

		lszdev zfcp-host $ZFCP_HOST --online | grep $ZFCP_HOST
		assert_warn $? 0 "Active configuration online"

		lszdev zfcp-host $ZFCP_HOST --configured | grep $ZFCP_HOST
		assert_warn $? 0 "Persistent configuration online"

end_section 0

clean

exit 0
