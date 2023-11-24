#!/bin/bash
#
# MACVLANs on top of VLANs on same physical interface
#
# - eth1 is not created or deleted by wicked on shutdown
# - eth1.* vlans are created and deleted by wicked/kernel on shutdown
# - macvlan* are created and deleted by wicked/kernel on shutdown (of eth1.*)
#
#
# setup:
#     eth1  <-l-  eth1.11  <-l-  macvlan1
#           <-l-  eth1.12  <-l-  macvlan2
#

eth0="${eth0:-eth0}"
eth0_ip=${eth0_ip:-10.0.0.1/24}

vlan0_id=10
vlan0="${vlan0:-$eth0.$vlan0_id}"
vlan0_ip="${vlan0_ip:-10.1.0.1/24}"

vlan1_id=20
vlan1="${vlan1:-$eth0.$vlan1_id}"
vlan1_ip="${vlan1_ip:-10.1.1.1/24}"

macvlan0="${macvlan0:-macvlan0}"
macvlan0_ip="${macvlan0_ip:-10.5.0.1/24}"

macvlan1="${macvlan1:-macvlan1}"
macvlan1_ip="${macvlan1_ip:-10.5.1.1/24}"

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

	cat >"${dir}/ifcfg-${vlan1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${eth0}'
		VLAN_ID=${vlan1_id}
		${vlan1_ip:+IPADDR='${vlan0_ip}'}
	EOF

	cat >"${dir}/ifcfg-${macvlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		MACVLAN_DEVICE='${vlan0}'
		${macvlan0_ip:+IPADDR='${macvlan0_ip}'}
	EOF

	cat >"${dir}/ifcfg-${macvlan1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		MACVLAN_DEVICE='${vlan1}'
		${macvlan1_ip:+IPADDR='${macvlan1_ip}'}
	EOF

   	{
		for dev in $eth0 $vlan0 $vlan1 $macvlan0 $macvlan1; do
			echo "== "${dir}/ifcfg-${dev}" =="
			cat "${dir}/ifcfg-${dev}"
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $eth0"

	echo "# wicked $wdebug ifup $cfg $eth0"
	wicked $wdebug ifup $cfg $eth0
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown $eth0
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_down "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_eth0=step2

step3()
{
	bold "=== step $step: ifup --links $eth0"

	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifup $cfg --links $eth0"
	wicked $wdebug ifup $cfg --links $eth0
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_up "$vlan1"
	check_device_is_up "$macvlan0"
	check_device_is_up "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	has_wicked_support ifup --links || return
	$ifdown_eth0
}

step5()
{
	bold "=== step $step: ifup $vlan0"

	echo "# wicked $wdebug ifup $cfg $vlan0"
	wicked $wdebug ifup $cfg "$vlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	bold "=== step $step: ifdown $vlan0"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown "$vlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	bold "=== step $step: ifup --links $vlan0"

	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifup $cfg --links $vlan0"
	wicked $wdebug ifup $cfg --links "$vlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_up "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	$ifdown_eth0
}


step9()
{
	bold "=== step $step: ifup $vlan1"

	echo "# wicked $wdebug ifup $cfg $vlan1"
	wicked $wdebug ifup $cfg "$vlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_up "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	bold "=== step $step: ifdown $vlan1"

	echo "# wicked $wdebug ifdown $vlan1"
	wicked $wdebug ifdown "$vlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	bold "=== step $step: ifup --links $vlan1"

	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifup $cfg --links $vlan1"
	wicked $wdebug ifup $cfg --links "$vlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_up "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_up "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step12()
{
	$ifdown_eth0
}

step13()
{
	bold "=== step $step: ifup $macvlan0"

	echo "# wicked $wdebug ifup $cfg $macvlan0"
	wicked $wdebug ifup $cfg "$macvlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_up "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step14()
{
	bold "=== step $step: ifdown $macvlan0"

	echo "# wicked $wdebug ifdown $macvlan0"
	wicked $wdebug ifdown "$macvlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step15()
{
	bold "=== step $step: ifup --links $macvlan0"

	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifup $cfg --links $macvlan0"
	wicked $wdebug ifup $cfg --links "$macvlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_up "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step16()
{
	bold "=== step $step: ifdown $vlan0"
	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown "$vlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}


step17()
{
	$ifdown_eth0
}

step18()
{
	bold "=== step $step: ifup $macvlan1"

	echo "# wicked $wdebug ifup $cfg $macvlan1"
	wicked $wdebug ifup $cfg "$macvlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_up "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_up "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step19()
{
	bold "=== step $step: ifdown $macvlan1"

	echo "# wicked $wdebug ifdown $macvlan1"
	wicked $wdebug ifdown "$macvlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_up "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step20()
{
	bold "=== step $step: ifup --links $macvlan1"

	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifup $cfg --links $macvlan1"
	wicked $wdebug ifup $cfg --links "$macvlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_up "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step21()
{
	bold "=== step $step: ifdown $vlan1"
	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifdown $vlan1"
	wicked $wdebug ifdown "$vlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_down "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step21()
{
	$ifdown_eth0
}


step23()
{
	bold "=== step $step: ifup $macvlan0 $macvlan1"

	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifup $cfg $macvlan0 $macvlan1"
	wicked $wdebug ifup $cfg "$macvlan0" "$macvlan1"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$vlan0"
	check_device_is_up "$vlan1"
	check_device_is_up "$macvlan0"
	check_device_is_up "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step24()
{
	bold "=== step $step: ifdown $vlan0"
	has_wicked_support ifup --links || return

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown "$vlan0"
	echo ""

	print_device_status "$eth0" "$vlan0" "$vlan1" "$macvlan0" "$macvlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$vlan0"
	check_device_is_up "$vlan1"
	check_device_is_down "$macvlan0"
	check_device_is_up "$macvlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$macvlan1" "$macvlan0" "$vlan1" "$vlan0" "$eth0"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../lib/common.sh
