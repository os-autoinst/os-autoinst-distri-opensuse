#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"

ovsbrA="${ovsbrA:-ovsbrA}"
ovsbrA_ip4="${ovsbrA_ip4:-198.18.10.10/24}"

ovsbrB="${ovsbrB:-ovsbrB}"
ovsbrA_vlan_id="${ovsbrA_vlan_id:-10}"
ovsbrB_ip4="${ovsbrB_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT

	OVS VLAN 1 Bridge with Parent-Bridge on physical interface

	- ovsbrA is a bridge with physical port nicB (untagged nicB traffic)
	- ovsbrB refers to ovsbrA as parent with vlan 1 (tagged nicB traffic)

	setup:

	    $nicB   -m->    $ovsbrA   <-l-    $ovsbrB.$ovsbrA_vlan_id



	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"

	print_test_description

	cat >"${dir}/ifcfg-${nicA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${ovsbrA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${ovsbrA_ip4:+IPADDR='${ovsbrA_ip4}'}
		OVS_BRIDGE='yes'
		OVS_BRIDGE_PORT_DEVICE_1='$nicA'
	EOF

	cat >"${dir}/ifcfg-${ovsbrB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		${ovsbrB_ip4:+IPADDR='${ovsbrB_ip4}'}
		OVS_BRIDGE='yes'
		OVS_BRIDGE_VLAN_PARENT='$ovsbrA'
		OVS_BRIDGE_VLAN_TAG='$ovsbrA_vlan_id'
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$nicA" "$ovsbrA" "$ovsbrB"; do
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
	bold "=== step $step: ifup $nicA"

	echo "# wicked $wdebug ifup $cfg $nicA"
	wicked $wdebug ifup $cfg "$nicA"
	echo ""

	print_device_status "$nicA" "$ovsbrA" "$ovsbrB"

	check_device_is_up "$nicA"
	check_device_is_up "$ovsbrA"
	check_device_is_down "$ovsbrB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $ovsbrA"

	echo "# wicked $wdebug ifdown $ovsbrA"
	wicked $wdebug ifdown "$ovsbrA"
	echo ""

	print_device_status "$nicA" "$ovsbrA" "$ovsbrB"

	check_device_is_down "$nicA"
	check_device_is_down "$ovsbrA"
	check_device_is_down "$ovsbrB"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step2

step3()
{
	bold "=== step $step: ifup $ovsbrA"

	echo "# wicked $wdebug ifup $cfg $ovsbrA"
	wicked $wdebug ifup $cfg "$ovsbrA"
	echo ""

	print_device_status "$nicA" "$ovsbrA" "$ovsbrB"

	check_device_is_up "$nicA"
	check_device_is_up "$ovsbrA"
	check_device_is_down "$ovsbrB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	$ifdown_all
}

step5()
{
	bold "=== step $step: ifup $ovsbrB"

	echo "# wicked $wdebug ifup $cfg $ovsbrB"
	wicked $wdebug ifup $cfg "$ovsbrB"
	echo ""

	print_device_status "$nicA" "$ovsbrA" "$ovsbrB"

	check_device_is_up "$nicA"
	check_device_is_up "$ovsbrA"
	check_device_is_up "$ovsbrB"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_all=step5

step6()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$ovsbrA" "$ovsbrB"

	check_device_is_down "$nicA"
	check_device_is_up "$ovsbrA"
	check_device_is_up "$ovsbrB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	$ifup_all
}

step8()
{
	bold "=== step $step: ifdown $ovsbrA"

	echo "# wicked $wdebug ifdown $ovsbrA"
	wicked $wdebug ifdown "$ovsbrA"
	echo ""

	print_device_status "$nicA" "$ovsbrA" "$ovsbrB"

	check_device_is_down "$nicA"
	check_device_is_down "$ovsbrA"
	check_device_is_down "$ovsbrB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step9()
{
	$ifup_all
}

step10()
{
	bold "=== step $step: ifdown $ovsbrB"

	echo "# wicked $wdebug ifdown $ovsbrB"
	wicked $wdebug ifdown "$ovsbrB"
	echo ""

	print_device_status "$nicA" "$ovsbrA" "$ovsbrB"

	check_device_is_up "$nicA"
	check_device_is_up "$ovsbrA"
	check_device_is_down "$ovsbrB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$nicA" "$ovsbrA" "$ovsbrB"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
