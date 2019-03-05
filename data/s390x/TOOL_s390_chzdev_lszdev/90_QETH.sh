# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 90_QETH.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f qeth.conf
	chzdev $QETH performance_stats=0
	chzdev $QETH bridge_reflect_promisc=none
	chzdev $QETH -y -d
	chzdev $QETH buffer_count=64
	chzdev --type qeth -y --remove-all
	chzdev $QETH -y --remove-all
	chzdev $QETH -y -d
	chchp -v 0 $QETH_CHPID
	chchp -c 0 $QETH_CHPID
}

start_section 0 "90 QETH test"

if grep -q 90_QETH omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi

		chchp -v 1 $QETH_CHPID
		chchp -c 1 $QETH_CHPID
		sleep 10
		#device online and displayed as persistent online and active online?
		lsqeth | grep $ENCCW
		assert_fail $? 0 "QETH $QETH is online"

		lszdev $QETH --online | grep $QETH
		assert_warn $? 0 "Active configuration online"

		lszdev $QETH --configured | grep $QETH
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		#depends on patch not yet in distro
		lszdev $QETH -i | grep performance_stats | awk '{print $2}' | grep 1
		assert_warn $? 0 "performance_stats=1"

		lszdev $QETH -i | grep buffer_count | awk '{print $2}' | grep 32
		assert_warn $? 0 "buffer_count=32"

		#change device driver configuration (#2)

		#detach device
		isVM
		if [[ $? -ne 0 ]];then
			assert_exec 0 "chchp -c 0 $QETH_CHPID"
			assert_exec 0 "chchp -v 0 $QETH_CHPID"
			sleep 10
			#device offline and displayed as persistent online and active online?
			lszdev $QETH --online | grep $QETH
			assert_warn $? 1 "Active configuration offline"

			lszdev $QETH --configured | grep $QETH
			assert_warn $? 0 "Persistent configuration online"

			lsqeth | grep $ENCCW
			assert_fail $? 1 "QETH $QETH is offline"
			#re-atach device
			assert_exec 0 "chchp -c 1 $QETH_CHPID"
			assert_exec 0 "chchp -v 1 $QETH_CHPID"
		else
                        assert_exec 0 "chzdev $QETH -y -a -d"
                        assert_exec 0 "chzdev $QETH -a -e"
                fi
		sleep 10
		#device online and displayed as persistent online and active onöine?
		lsqeth | grep $ENCCW
		assert_fail $? 0 "QETH $QETH is online"

		lszdev $QETH --online | grep $QETH
		assert_warn $? 0 "Active configuration online" #1

		lszdev $QETH --configured | grep $QETH
		assert_warn $? 0 "Persistent configuration online"
		#device driver configuration (#2) ?

		#change device and device driver configuration (#3)
		assert_exec 0 "chzdev $QETH -y --remove-all"

		#unload device drivers ( impossible due to qeth_l2 in-kernel dependency ? and lose of connection to tp4)
		#device offline and displayed as persistent online and active online?
		#reload device drivers
		#device online and displayed as persistent online and active online?
		#device and device driver configuration (#3) ?

		#device persistent off
		assert_exec 0 "chzdev qeth $QETH -y -p -d"
		#device online and displayed as persistent offline and active online?
		lsqeth | grep $ENCCW
		assert_fail $? 0 "QETH $QETH is online"

		lszdev $QETH --online | grep $QETH
		assert_warn $? 0 "Active configuration online" #1

		lszdev $QETH --configured | grep $QETH
		assert_warn $? 1 "Persistent configuration offline"
		#detach device
		isVM
		if [[ $? -ne 0 ]];then
			assert_exec 0 "chchp -c 0 $QETH_CHPID"
			assert_exec 0 "chchp -v 0 $QETH_CHPID"
			sleep 10
			#device offline and displayed as persistent offline and active offline?
			lsqeth | grep $ENCCW
			assert_fail $? 1 "QETH $QETH is offline"

			lszdev $QETH --online | grep $QETH
			assert_warn $? 1 "Active configuration offline"

			lszdev $QETH-$QETH --configured | grep $QETH
			assert_warn $? 1 "Persistent configuration offline"
			#re-attach device
			assert_exec 0 "chchp -c 1 $QETH_CHPID"
			assert_exec 0 "chchp -v 1 $QETH_CHPID"
		else
                        assert_exec 0 "chzdev $QETH -y -a -d"
                        assert_exec 0 "chzdev $QETH -a -e"
                fi
		sleep 10
		#load configuration
		assert_exec 0 "chzdev --import qeth.conf -p"
		assert_exec 0 "chzdev $QETH --apply"
		#device online and displayed as persistent online and active online?
		lsqeth | grep $ENCCW
		assert_fail $? 0 "QETH $QETH is online"

		lszdev $QETH --online | grep $QETH
		assert_warn $? 0 "Active configuration online"

		lszdev $QETH --configured | grep $QETH
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		#depends on patch not yet in distro
		lszdev $QETH -i | grep performance_stats | awk '{print $2}' | grep 1
		assert_warn $? 0 "performance_stats=1"

end_section 0

clean

exit 0
