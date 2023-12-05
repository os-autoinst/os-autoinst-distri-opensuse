#!/bin/bash
#
# OVS VLAN 1 Bridge with Parent-Bridge on physical interface
#
# - ovsbr0 is a bridge with physical port eth1 (untagged eth1 traffic)
# - ovsbr1 refers to ovsbr0 as parent with vlan 1 (tagged eth1 traffic)
#
# setup:
#
#     eth1   -m->    ovsbr0   <-l-    ovsbr1
#

eth0="${eth0:-eth0}"

ovsbr0="${ovsbr0:-ovsbr0}"
ovsbr0_ip4="${ovsbr0_ip4:-198.18.12.1/24}"

ovsbr1="${ovsbr1:-ovsbr1}"
ovsbr1_vlan_id="${ovsbr1_vlan_id:-10}"
ovsbr1_ip4="${ovsbr1_ip4:-198.18.13.1/24}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${eth0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${ovsbr0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${ovsbr0_ip4:+IPADDR='${ovsbr0_ip4}'}
		OVS_BRIDGE='yes'
		OVS_BRIDGE_PORT_DEVICE_1='$eth0'
	EOF

	cat >"${dir}/ifcfg-${ovsbr1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		${ovsbr1_ip4:+IPADDR='${ovsbr1_ip4}'}
		OVS_BRIDGE='yes'
		OVS_BRIDGE_VLAN_PARENT='$ovsbr0'
		OVS_BRIDGE_VLAN_TAG='$ovsbr1_vlan_id'
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$eth0" "$ovsbr0" "$ovsbr1"; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	echo "== wicked show-config"
	wicked show-config | tee "config-step-${step}.xml"

	systemctl is-active openvswitch || systemctl start openvswitch || {
		echo "ERROR: Start openvswitch failed - retry now";
		sleep 1;
		if ! systemctl start openvswitch; then
			journalctl -xe --no-pager
			systemctl status openvswitch
			exit 2
		fi;
	}

}

step1()
{
	bold "=== step $step: ifup $eth0"

	echo "# wicked $wdebug ifup $cfg $eth0"
	wicked $wdebug ifup $cfg "$eth0"
	echo ""

	print_device_status "$eth0" "$ovsbr0" "$ovsbr1"

	check_device_is_up "$eth0"
	check_device_is_down "$ovsbr0"
	check_device_is_up "$ovsbr1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $ovsbr0"

	echo "# wicked $wdebug ifdown $ovsbr0"
	wicked $wdebug ifdown "$ovsbr0"
	echo ""

	print_device_status "$eth0" "$ovsbr0" "$ovsbr1"

	check_device_is_down "$eth0"
	check_device_is_down "$ovsbr0"
	check_device_is_down "$ovsbr1"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step2

step3()
{
	bold "=== step $step: ifup $ovsbr0"

	echo "# wicked $wdebug ifup $cfg $ovsbr0"
	wicked $wdebug ifup $cfg "$ovsbr0"
	echo ""

	print_device_status "$eth0" "$ovsbr0" "$ovsbr1"

	check_device_is_up "$eth0"
	check_device_is_up "$ovsbr0"
	check_device_is_down "$ovsbr1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	$ifdown_all
}

step5()
{
	bold "=== step $step: ifup $ovsbr1"

	echo "# wicked $wdebug ifup $cfg $ovsbr1"
	wicked $wdebug ifup $cfg "$ovsbr1"
	echo ""

	print_device_status "$eth0" "$ovsbr0" "$ovsbr1"

	check_device_is_up "$eth0"
	check_device_is_up "$ovsbr0"
	check_device_is_up "$ovsbr1"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_all=step5

step6()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$ovsbr0" "$ovsbr1"

	check_device_is_down "$eth0"
	check_device_is_up "$ovsbr0"
	check_device_is_up "$ovsbr1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	$ifup_all
}

step8()
{
	bold "=== step $step: ifdown $ovsbr0"

	echo "# wicked $wdebug ifdown $ovsbr0"
	wicked $wdebug ifdown "$ovsbr0"
	echo ""

	print_device_status "$eth0" "$ovsbr0" "$ovsbr1"

	check_device_is_down "$eth0"
	check_device_is_down "$ovsbr0"
	check_device_is_down "$ovsbr1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step9()
{
	$ifup_all
}

step10()
{
	bold "=== step $step: ifdown $ovsbr1"

	echo "# wicked $wdebug ifdown $ovsbr1"
	wicked $wdebug ifdown "$ovsbr1"
	echo ""

	print_device_status "$eth0" "$ovsbr0" "$ovsbr1"

	check_device_is_up "$eth0"
	check_device_is_up "$ovsbr0"
	check_device_is_down "$ovsbr1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$eth0" "$ovsbr0" "$ovsbr1"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../lib/common.sh
