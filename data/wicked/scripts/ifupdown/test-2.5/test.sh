#!/bin/bash
#
# VLAN on Team of physical interfaces
#
# setup:
#
#     eth0,eth1   -m->    team0   <-l-    team0.10
#

eth0="${eth0:-eth0}"
eth1="${eth1:-eth1}"

team0="${team0:-team0}"
team0_ip4="${team0_ip4:-198.18.10.1/24}"

vlan0_id=10
vlan0="${vlan0:-$team0.$vlan0_id}"
vlan0_ip4="${vlan0_ip4:-198.18.2.1/24}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${eth0}" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${eth1}" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${team0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${team0_ip4:+IPADDR='${team0_ip4}'}
		TEAM_RUNNER=activebackup
		TEAM_PORT_DEVICE_1="$eth0"
		TEAM_PORT_DEVICE_2="$eth1"
	EOF

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${team0}'
		VLAN_ID=${vlan0_id}
		${vlan0_ip4:+IPADDR='${vlan0_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$eth0" "$eth1" "$team0" "$vlan0"; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	echo "== wicked show-config"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $eth0"

	echo "# wicked $wdebug ifup $cfg $eth0"
	wicked $wdebug ifup $cfg "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$team0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$team0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	bold "=== step $step: ifdown $team0"

	echo "# wicked $wdebug ifdown $team0"
	wicked $wdebug ifdown "$team0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$team0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step3

step4()
{
	bold "=== step $step: ifup $eth1"

	echo "# wicked $wdebug ifup $cfg $eth1"
	wicked $wdebug ifup $cfg "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$team0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth0"
	check_device_is_up "$team0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	$ifdown_all
}

step7()
{
	bold "=== step $step: ifup $team0"

	echo "# wicked $wdebug ifup $cfg $team0"
	wicked $wdebug ifup $cfg "$team0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$team0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	$ifdown_all
}

step9()
{
	bold "=== step $step: ifup $vlan0"

	echo "# wicked $wdebug ifup $cfg $vlan0"
	wicked $wdebug ifup $cfg "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$team0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$team0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	bold "=== step $step: ifdown $eth1"

	echo "# wicked $wdebug ifdown $eth1"
	wicked $wdebug ifdown "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$team0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step12()
{
	bold "=== step $step: ifdown $vlan0"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$team0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$team0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlan0" "$eth0" "$eth1" "$team0"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../lib/common.sh
