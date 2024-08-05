#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicA_ip4=${nicA_ip4:-198.18.10.10/24}

vlanA_id=10
vlanA="${vlanA:-$nicA.$vlanA_id}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

macvlanA="${macvlanA:-macvlanA}"
macvlan0_ip4="${macvlan0_ip4:-198.18.10.101/24}"

test_description()
{
	cat - <<-EOT

	MACVLAN on VLAN on physical interface

	setup:
	   nicA    <-l-    nicA.11    <-l-    macvlanA

	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"

	print_test_description

	cat >"${dir}/ifcfg-${nicA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		${nicA_ip4:+IPADDR='${nicA_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${nicA}'
		VLAN_ID=${vlanA_id}
		${vlanA_ip4:+IPADDR='${vlanA_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${macvlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		MACVLAN_DEVICE='${vlanA}'
		${macvlan0_ip4:+IPADDR='${macvlan0_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' $BASH_SOURCE
		echo ""
		for dev in "$nicA" "$vlanA" "$macvlanA"; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $nicA"

	echo "# wicked $wdebug ifup $cfg $nicA"
	wicked $wdebug ifup $cfg $nicA
	echo ""

	print_device_status "$nicA" "$vlanA" "$macvlanA"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_down "$macvlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown $nicA
	echo ""

	print_device_status "$nicA" "$vlanA" "$macvlanA"

	check_device_is_down "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_down "$macvlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step2

step3()
{
	bold "=== step $step: ifup $vlanA"

	echo "# wicked $wdebug ifup $cfg $vlanA"
	wicked $wdebug ifup $cfg $vlanA
	echo ""

	print_device_status "$nicA" "$vlanA" "$macvlanA"

	check_device_is_up "$nicA"
	check_device_is_up "$vlanA"
	check_device_is_down "$macvlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	bold "=== step $step: ifdown $vlanA"

	echo "# wicked $wdebug ifdown $vlanA"
	wicked $wdebug ifdown $vlanA
	echo ""

	print_device_status "$nicA" "$vlanA" "$macvlanA"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_down "$macvlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	bold "=== step $step: ifup $macvlanA"

	echo "# wicked $wdebug ifup $cfg $macvlanA"
	wicked $wdebug ifup $cfg $macvlanA
	echo ""

	print_device_status "$nicA" "$vlanA" "$macvlanA"

	check_device_is_up "$nicA"
	check_device_is_up "$vlanA"
	check_device_is_up "$macvlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	$ifdown_all
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$macvlanA" "$vlanA" "$nicA"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
