#!/bin/bash
#
#
# MACVLAN on VLAN on physical interface
#
# setup:
#    eth0    <-l-    eth0.11    <-l-    macvlan0
#

eth0="${eth0:-eth0}"
eth0_ip=${eth0_ip:-10.0.0.1/24}

vlan0_id=10
vlan0="${vlan0:-$eth0.$vlan0_id}"
vlan0_ip="${vlan0_ip:-10.1.0.1/24}"

macvlan0="${macvlan0:-macvlan0}"
macvlan0_ip="${macvlan0_ip:-10.5.0.1/24}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${eth0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		${eth0_ip:+IPADDR='${eth0_ip}'}
	EOF

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${eth0}'
		VLAN_ID=${vlan0_id}
		${vlan0_ip:+IPADDR='${vlan0_ip}'}
	EOF

	cat >"${dir}/ifcfg-${macvlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		MACVLAN_DEVICE='${vlan0}'
		${macvlan0_ip:+IPADDR='${macvlan0_ip}'}
	EOF

   	{
		echo "== "${dir}/ifcfg-${eth0}" =="
		cat "${dir}/ifcfg-${eth0}"
		echo "== "${dir}/ifcfg-${vlan0}" =="
		cat "${dir}/ifcfg-${vlan0}"
		echo "== "${dir}/ifcfg-${macvlan0}" =="
		cat "${dir}/ifcfg-${macvlan0}"
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $eth0"

	echo "# wicked $wdebug ifup $cfg $eth0"
	wicked $wdebug ifup $cfg $eth0
	echo ""

	print_device_status "$eth0" "$vlan0" "$macvlan0"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$macvlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown $eth0
	echo ""

	print_device_status "$eth0" "$vlan0" "$macvlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$macvlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step2

step5()
{
	bold "=== step $step: ifup $vlan0"

	echo "# wicked $wdebug ifup $cfg $vlan0"
	wicked $wdebug ifup $cfg $vlan0
	echo ""

	print_device_status "$eth0" "$vlan0" "$macvlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_down "$macvlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	bold "=== step $step: ifdown $vlan0"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown $vlan0
	echo ""

	print_device_status "$eth0" "$vlan0" "$macvlan0"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$macvlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step9()
{
	bold "=== step $step: ifup $macvlan0"

	echo "# wicked $wdebug ifup $cfg $macvlan0"
	wicked $wdebug ifup $cfg $macvlan0
	echo ""

	print_device_status "$eth0" "$vlan0" "$macvlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_up "$macvlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	$ifdown_all
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$macvlan0" "$vlan0" "$eth0"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../lib/common.sh
