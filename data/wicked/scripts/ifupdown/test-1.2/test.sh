#!/bin/bash
#
# VLAN on physical interface
#
#  - eth1 is not created or deleted by wicked on shutdown
#
# setup:
#
#    dummy0    <-l-    dummy0.11
#
# TODO: change vlan0 default name to dummy0.10

dummy0="${dummy0:-dummy0}"
dummy0_ip="${dummy0_ip:-10.3.0.1/24}"

vlan0_id="${vlan0_id:-10}"
#vlan0="${vlan0:-$dummy0.$vlan0_id}"
vlan0="${vlan0:-vlan$vlan0_id}"
vlan0_ip="${vlan0_ip:-10.1.0.1/24}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${dummy0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${dummy0_ip:+IPADDR='${dummy0_ip}'}
	EOF

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${vlan0_ip:+IPADDR='${vlan0_ip}'}
		ETHERDEVICE='${dummy0}'
		VLAN_ID='${vlan0_id}'
	EOF

	{
		echo "== "${dir}/ifcfg-${dummy0}" =="
		cat "${dir}/ifcfg-${dummy0}"
		echo "== "${dir}/ifcfg-${vlan0}" =="
		cat "${dir}/ifcfg-${vlan0}"
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup ${dummy0}"

	echo "# wicked $wdebug ifup $cfg ${dummy0}"
	wicked $wdebug ifup $cfg ${dummy0}
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_up "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown ${dummy0}"

	echo "# wicked $wdebug ifdown $dummy0"
	wicked $wdebug ifdown $dummy0
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_down "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_dummy0=step2

step3()
{
	has_wicked_support ifup --links || return
	bold "=== step $step: ifup --links ${dummy0}"

	echo "# wicked $wdebug ifup $cfg --links ${dummy0}"
	wicked $wdebug ifup $cfg --links "$dummy0"
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_up "$dummy0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	has_wicked_support ifup --links || return
	$ifdown_dummy0
}

step5()
{
	bold "=== step $step: ifup ${vlan0}"

	echo "# wicked $wdebug ifup $cfg ${vlan0}"
	wicked $wdebug ifup $cfg ${vlan0}
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_up "$dummy0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_vlan0=step5

step6()
{
	bold "=== step $step: ifdown ${dummy0}"

	echo "# wicked $wdebug ifdown $dummy0"
	wicked $wdebug ifdown $dummy0
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_down "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	$ifup_vlan0
}

step8()
{
	bold "=== step $step: ifdown ${vlan0}"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown $vlan0
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_up "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlan0" "$dummy0"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done

	echo ""
	echo "=== step $step: finished with $err errors"
}

. ../lib/common.sh
