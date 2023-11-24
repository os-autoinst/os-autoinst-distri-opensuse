#!/bin/bash
#
# VLAN on physical interface
#
#  - eth1 is not created or deleted by wicked on shutdown
#
# setup:
#
#    eth1    <-l-    eth1.11
#

eth0="${eth0:-eth0}"
eth0_ip="${vlan_ip:-10.0.0.1/24}"

vlan0_id="${vlan0_id:-10}"
vlan0_ip="${vlan0_ip:-10.1.0.1/24}"
vlan0="${vlan0:-$eth0.$vlan0_id}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${eth0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${eth0_ip:+IPADDR='${eth0_ip}'}
	EOF

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${vlan0_ip:+IPADDR='${vlan0_ip}'}
		ETHERDEVICE='${eth0}'
		VLAN_ID='${vlan0_id}'
	EOF

	{
		echo "== "${dir}/ifcfg-${eth0}" =="
		cat "${dir}/ifcfg-${eth0}"
		echo "== "${dir}/ifcfg-${vlan0}" =="
		cat "${dir}/ifcfg-${vlan0}"
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup ${eth0}"

	echo "# wicked $wdebug ifup $cfg ${eth0}"
	wicked $wdebug ifup $cfg ${eth0}
	echo ""

	print_device_status "$eth0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown ${eth0}"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown $eth0
	echo ""

	print_device_status "$eth0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_eth0=step2

step3()
{
	has_wicked_support ifup --links || return
	bold "=== step $step: ifup --links ${eth0}"

	echo "# wicked $wdebug ifup $cfg --links ${eth0}"
	wicked $wdebug ifup $cfg --links ${eth0}
	echo ""

	print_device_status "$eth0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	has_wicked_support ifup --links || return
	$ifdown_eth0
}

step3()
{
	bold "=== step $step: ifup ${vlan0}"

	echo "# wicked $wdebug ifup $cfg ${vlan0}"
	wicked $wdebug ifup $cfg ${vlan0}
	echo ""

	print_device_status "$eth0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_vlan0=step3

step4()
{
	bold "=== step $step: ifdown ${eth0}"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown $eth0
	echo ""

	print_device_status "$eth0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
    $ifup_vlan0
}

step6()
{
	bold "=== step $step: ifdown ${vlan0}"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown $vlan0
	echo ""

	print_device_status "$eth0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlan0" "$eth0"; do
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
