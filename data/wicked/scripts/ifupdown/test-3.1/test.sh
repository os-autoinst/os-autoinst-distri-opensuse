#!/bin/bash
#
# Bridges on Bond interface and it's VLAN
#
# setup:
#
#    eth0,eth1   -m->    bond0            -m->   br0
#                        ^
#                        +-l-    vlan0    -m->   br1
#
#

eth0="${eth0:-eth0}"
eth1="${eth1:-eth1}"

bond0="${bond0:-bond0}"
bond0_ip4="${bond0_ip4:-198.18.5.1/24}"

vlan0_id=10
vlan0="${vlan0:-$bond0.$vlan0_id}"

br0="${br0:-br0}"
br0_ip4="${br0_ip4:-198.18.8.1/24}"

br1="${br1:-br1}"
br1_ip4="${br1_ip4:-198.18.9.1/24}"


step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-$eth0" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$eth1" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${bond0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ZONE=trusted
		BONDING_MASTER=yes
		BONDING_MODULE_OPTS='mode=active-backup miimon=100'
		BONDING_SLAVE_0="$eth0"
		BONDING_SLAVE_1="$eth1"
	EOF

	cat >"${dir}/ifcfg-$vlan0" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='$bond0'
		VLAN_ID='$vlan0_id'
	EOF

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		BRIDGE=yes
		BRIDGE_PORTS=$bond0
		${br0_ip4:+IPADDR='${br0_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${br1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		BRIDGE=yes
		BRIDGE_PORTS=$vlan0
		${br1_ip4:+IPADDR='${br1_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1" ; do
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

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $br0"

	echo "# wicked $wdebug ifdown $br0"
	wicked $wdebug ifdown "$br0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_br0=step2

step3()
{
	bold "=== step $step: ifup $eth1"

	echo "# wicked $wdebug ifup $cfg $eth1"
	wicked $wdebug ifup $cfg "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	$ifdown_br0
}

step5()
{
	bold "=== step $step: ifup $bond0"

	echo "# wicked $wdebug ifup $cfg $bond0"
	wicked $wdebug ifup $cfg "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	$ifdown_br0
}

step7()
{
	bold "=== step $step: ifup $br0"

	echo "# wicked $wdebug ifup $cfg $br0"
	wicked $wdebug ifup $cfg "$br0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	$ifdown_br0
}

step9()
{
	bold "=== step $step: ifup $vlan0"

	echo "# wicked $wdebug ifup $cfg $vlan0"
	wicked $wdebug ifup $cfg "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"
	check_device_is_up "$br0"
	check_device_is_up "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_all=step9

step10()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"
	check_device_is_up "$br0"
	check_device_is_up "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	bold "=== step $step: ifdown $eth1"

	echo "# wicked $wdebug ifdown $eth1"
	wicked $wdebug ifdown "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"
	check_device_is_up "$br0"
	check_device_is_up "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step12()
{
	bold "=== step $step: ifdown $br0 $br1"

	echo "# wicked $wdebug ifdown $br0 $br1"
	wicked $wdebug ifdown "$br0" "$br1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step12

step13()
{
	bold "=== step $step: ifup $br0"

	echo "# wicked $wdebug ifup $cfg $br0"
	wicked $wdebug ifup $cfg "$br0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step14()
{
	$ifdown_br0
}

step15()
{
	bold "=== step $step: ifup $br1"

	echo "# wicked $wdebug ifup $cfg $br1"
	wicked $wdebug ifup $cfg "$br1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"
	check_device_is_up "$br0"
	check_device_is_up "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step16()
{
	bold "=== step $step: ifdown $bond0"

	echo "# wicked $wdebug ifdown $bond0"
	wicked $wdebug ifdown "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_up "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step17()
{
	$ifup_all
}

step18()
{
	bold "=== step $step: ifdown $vlan0"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_up "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step19()
{
	$ifup_all
}

step20()
{
	bold "=== step $step: ifdown $br0"

	echo "# wicked $wdebug ifdown $br0"
	wicked $wdebug ifdown "$br0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$br0"
	check_device_is_up "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step21()
{
	$ifup_all
}

step22()
{
	bold "=== step $step: ifdown $br1"

	echo "# wicked $wdebug ifdown $br1"
	wicked $wdebug ifdown "$br1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$br0"
	check_device_is_down "$br1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$eth0" "$eth1" "$bond0" "$vlan0" "$br0" "$br1"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown "$dev"
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../lib/common.sh
