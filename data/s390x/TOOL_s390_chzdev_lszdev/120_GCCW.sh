# Copyright (C) 2018 IBM Corp.
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.


#!/bin/bash
# Script-Name: 120_GCCW.sh
#

# Load testlib
for f in lib/*.sh; do source $f; done
source CONFIG.sh || exit 1

function clean() {
	rm -f gccw.conf
	chzdev $GCCW cmb_enable=0
	chzdev $GCCW -y --remove-all
	chzdev $GCCW -d
}

isVM
if [[ $? -eq 0 ]];then
start_section 0 "120 GCCW test"

if grep -q 120_GCCW omit; then
	assert_exec 0 "echo 'skipping this section'"
	end_section 0
	exit 0
fi
		#device online and displayed as persistent online and active online?
		lscss | grep ' 1403/00' |grep $GCCW | grep yes
		assert_fail $? 0 "GCCW $GCCW is online"

		lszdev $GCCW --online | grep $GCCW
		assert_warn $? 0 "Active configuration online"

		lszdev $GCCW --configured | grep $GCCW
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $GCCW -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

		#change device driver configuration (#2)
		assert_exec 0 "chzdev $GCCW cmb_enable=0"
		lszdev $GCCW -i | grep cmb_enable | grep 0
		assert_warn $? 0 "cmb_enable=0"
		#detach device
		#device offline and displayed as persistent online and active online?
		#re-atach device
		#device online and displayed as persistent online and active online?
		#device driver configuration (#2) ? nothing to do for GCCW
		#change device and device driver configuration (#3)

        assert_exec 0 "lsmod | grep -q vmur"

        if [[ $? -ne 0 ]];then
			#unload device drivers
			assert_exec 0 "modprobe -r vmur"
			#device offline and displayed as persistent online and active online?
			lscss | grep ' 1403/00' |grep $GCCW | grep yes
			assert_fail $? 1 "GCCW $GCCW is offline"

			lszdev $GCCW --online | grep $GCCW
			assert_warn $? 0 "Active configuration online"

			lszdev $GCCW --configured | grep $GCCW
			assert_warn $? 0 "Persistent configuration online"
			#reload device drivers
			assert_exec 0 "modprobe vmur"
		else
			assert_exec 0 "chzdev $GCCW -a -d"
			assert_exec 0 "chzdev $GCCW -a -e"
		fi
		#device online and displayed as persistent online and active online?
		lscss | grep ' 1403/00' |grep $GCCW | grep yes
		assert_fail $? 0 "GCCW $GCCW is online"

		lszdev $GCCW --online | grep $GCCW
		assert_warn $? 0 "Active configuration online"

		lszdev $GCCW --configured | grep $GCCW
		assert_warn $? 0 "Persistent configuration online"
		#device and device driver configuration (#2) ?
		lszdev $GCCW -i | grep cmb_enable | grep 0
		assert_warn $? 0 "cmb_enable=0"
		#device persistent off
		assert_exec 0 "chzdev $GCCW -p -d"
		#device online and displayed as persistent offline and active online?
		lscss | grep ' 1403/00' |grep $GCCW | grep yes
		assert_fail $? 0 "GCCW $GCCW is online"

		lszdev $GCCW --online | grep $GCCW
		assert_warn $? 0 "Active configuration online"

		lszdev $GCCW --configured | grep $GCCW
		assert_warn $? 1 "Persistent configuration offline"

		#load configuration
		assert_exec 0 "chzdev --import gccw.conf"
		#device online and displayed as persistent online and active online?
		lscss | grep ' 1403/00' |grep $GCCW | grep yes
		assert_fail $? 0 "GCCW $GCCW is online"

		lszdev $GCCW --online | grep $GCCW
		assert_warn $? 0 "Active configuration online"

		lszdev $GCCW --configured | grep $GCCW
		assert_warn $? 0 "Persistent configuration online"
		#has device configuration (#1) ?
		lszdev $GCCW -i | grep cmb_enable | grep 1
		assert_warn $? 0 "cmb_enable=1"

end_section 0

clean

fi
exit 0
