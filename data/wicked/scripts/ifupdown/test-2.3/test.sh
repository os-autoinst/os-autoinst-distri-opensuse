#!/bin/bash
#
# VLAN on Bond of physical interfaces
#
# setup:
#
#    eth1,eth2   -m->    bond0   <-l-    bond0.11
#

eth0="${eth0:-eth0}"
eth1="${eth1:-eth1}"

bond0="${bond0:-bond0}"
bond0_ip="${bond0_ip:-10.4.0.1/24}"

vlan0_id=10
vlan0="${vlan0:-$bond0.$vlan0_id}"
vlan0_ip="${vlan0_ip:-10.1.0.1/24}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${eth0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${eth1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${bond0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${bond0_ip:+IPADDR='${bond0_ip}'}
		BONDING_MASTER=yes
		BONDING_MODULE_OPTS='mode=active-backup miimon=100'
		BONDING_SLAVE_0="$eth0"
		BONDING_SLAVE_1="$eth1"
	EOF

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${bond0}'
		VLAN_ID=${vlan0_id}
		${vlan0_ip:+IPADDR='${vlan0_ip}'}
	EOF

   	{
		for dev in "$eth0" "$eth1" "$bond0" "$vlan0" ; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $eth0"

	echo "# wicked $wdebug ifup $cfg $eth0"
	wicked $wdebug ifup $cfg "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
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

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	has_wicked_support ifup --links || return
	bold "=== step $step: ifup --links $eth0"

	echo "# wicked $wdebug ifup $cfg --links $eth0"
	wicked $wdebug ifup $cfg --links "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	bold "=== step $step: ifdown $bond0"

	echo "# wicked $wdebug ifdown $bond0"
	wicked $wdebug ifdown "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_bond0=step4

step5()
{
	bold "=== step $step: ifup $eth1"

	echo "# wicked $wdebug ifup $cfg $eth1"
	wicked $wdebug ifup $cfg "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth0"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	has_wicked_support ifup --links || return
	bold "=== step $step: ifup --links $eth1"


	echo "# wicked $wdebug ifup $cfg --links $eth1"
	wicked $wdebug ifup $cfg --links "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	$ifdown_bond0
}

step9()
{
	bold "=== step $step: ifup $bond0"

	echo "# wicked $wdebug ifup $cfg $bond0"
	wicked $wdebug ifup $cfg "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	$ifdown_bond0
}

step11()
{
	has_wicked_support ifup --ports || return
	bold "=== step $step: ifup --ports $bond0"

	echo "# wicked $wdebug ifup $cfg --ports $bond0"
	wicked $wdebug ifup $cfg --ports "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step12()
{
	has_wicked_support ifup --ports || return
	$ifdown_bond0
}

step13()
{
	has_wicked_support ifup --links || return
	bold "=== step $step: ifup --links $bond0"

	echo "# wicked $wdebug ifup $cfg --links $bond0"
	wicked $wdebug ifup $cfg --links "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step14()
{
	has_wicked_support ifup --links || return
	$ifdown_bond0
}

step15()
{
	has_wicked_support ifup --ports --links || return
	bold "=== step $step: ifup --ports --links $bond0"

	echo "# wicked $wdebug ifup $cfg --ports --links $bond0"
	wicked $wdebug ifup $cfg --ports --links "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step16()
{
	has_wicked_support ifup --ports --links || return
	$ifdown_bond0
}

step17()
{
	bold "=== step $step: ifup $vlan0"

	echo "# wicked $wdebug ifup $cfg $vlan0"
	wicked $wdebug ifup $cfg "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step18()
{
	bold "=== step $step: ifdown $vlan0"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step19()
{
	has_wicked_support ifup --ports || return
	bold "=== step $step: ifup --ports $vlan0"

	echo "# wicked $wdebug ifup $cfg --ports $vlan0"
	wicked $wdebug ifup $cfg --ports "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step20()
{
	has_wicked_support ifup --ports && return
	bold "=== step $step: ifup $vlan0 $eth0 $eth1"

	echo "# wicked $wdebug ifup $cfg $vlan0 $eth0 $eth1"
	wicked $wdebug ifup $cfg "$vlan0" "$eth0" "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step21()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step22()
{
	bold "=== step $step: ifdown $eth1"

	echo "# wicked $wdebug ifdown $eth1"
	wicked $wdebug ifdown "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlan0" "$eth0" "$eth1" "$bond0"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../lib/common.sh
