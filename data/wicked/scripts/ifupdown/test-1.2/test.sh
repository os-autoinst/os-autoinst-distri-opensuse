#!/bin/bash


dummyA="${dummyA:-dummyA}"
dummyA_ip4="${dummyA_ip4:-198.18.10.10/24}"

vlanA_id="${vlanA_id:-10}"
#vlanA="${vlanA:-$dummyA.$vlanA_id}"
vlanA="${vlanA:-vlan$vlanA_id}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT

	VLAN on virtual interface

	setup:

	   $dummyA    <-l-    $vlanA

	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"

	print_test_description

	cat >"${dir}/ifcfg-${dummyA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		DUMMY=yes
		${dummyA_ip4:+IPADDR='${dummyA_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${vlanA_ip4:+IPADDR='${vlanA_ip4}'}
		ETHERDEVICE='${dummyA}'
		VLAN_ID='${vlanA_id}'
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' $BASH_SOURCE
		echo ""
		for dev in "$dummyA" "$vlanA" ; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup ${dummyA}"

	echo "# wicked $wdebug ifup $cfg ${dummyA}"
	wicked $wdebug ifup $cfg ${dummyA}
	echo ""

	print_device_status "$vlanA" "$dummyA"

	check_device_is_up "$dummyA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown ${dummyA}"

	echo "# wicked $wdebug ifdown $dummyA"
	wicked $wdebug ifdown $dummyA
	echo ""

	print_device_status "$vlanA" "$dummyA"

	check_device_is_down "$dummyA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	bold "=== step $step: ifup ${vlanA}"

	echo "# wicked $wdebug ifup $cfg ${vlanA}"
	wicked $wdebug ifup $cfg ${vlanA}
	echo ""

	print_device_status "$vlanA" "$dummyA"

	check_device_is_up "$dummyA"
	check_device_is_up "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_vlan0=step3

step4()
{
	bold "=== step $step: ifdown ${dummyA}"

	echo "# wicked $wdebug ifdown $dummyA"
	wicked $wdebug ifdown $dummyA
	echo ""

	print_device_status "$vlanA" "$dummyA"

	check_device_is_down "$dummyA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	$ifup_vlan0
}

step6()
{
	bold "=== step $step: ifdown ${vlanA}"

	echo "# wicked $wdebug ifdown $vlanA"
	wicked $wdebug ifdown $vlanA
	echo ""

	print_device_status "$vlanA" "$dummyA"

	check_device_is_up "$dummyA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlanA" "$dummyA"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done

	echo ""
	echo "=== step $step: finished with $err errors"
}

. ../../lib/common.sh
