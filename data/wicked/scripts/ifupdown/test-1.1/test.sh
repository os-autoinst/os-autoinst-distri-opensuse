#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicA_ip4="${nicA_ip4:-198.18.10.10/24}"

vlanA_id="${vlanA_id:-10}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"
vlanA="${vlanA:-$nicA.$vlanA_id}"

test_description()
{
	cat - <<-EOT

	VLAN on physical interface

	 - $nicB is not created or deleted by wicked on shutdown

	setup:

	   $nicB    <-l-    $vlanA

	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"

	print_test_description

	cat >"${dir}/ifcfg-${nicA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${nicA_ip4:+IPADDR='${nicA_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${vlanA_ip4:+IPADDR='${vlanA_ip4}'}
		ETHERDEVICE='${nicA}'
		VLAN_ID='${vlanA_id}'
	EOF

   	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' $BASH_SOURCE
		echo ""
		for dev in "$nicA" "$vlanA" ; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup ${nicA}"

	echo "# wicked $wdebug ifup $cfg ${nicA}"
	wicked $wdebug ifup $cfg ${nicA}
	echo ""

	print_device_status "$nicA" "$vlanA"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown ${nicA}"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown $nicA
	echo ""

	print_device_status "$nicA" "$vlanA"

	check_device_is_down "$nicA"
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

	print_device_status "$nicA" "$vlanA"

	check_device_is_up "$nicA"
	check_device_is_up "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_vlanA=step3

step4()
{
	bold "=== step $step: ifdown ${nicA}"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown $nicA
	echo ""

	print_device_status "$nicA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
    $ifup_vlanA
}

step6()
{
	bold "=== step $step: ifdown ${vlanA}"

	echo "# wicked $wdebug ifdown $vlanA"
	wicked $wdebug ifdown $vlanA
	echo ""

	print_device_status "$nicA" "$vlanA"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlanA" "$nicA"; do
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
