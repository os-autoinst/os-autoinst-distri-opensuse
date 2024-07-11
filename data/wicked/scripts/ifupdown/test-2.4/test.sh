#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"

vlanA_id=10
vlanA="${vlanA:-$nicA.$vlanA_id}"

bridgeA="${bridgeA:-bridgeA}"
bridgeA_ip4="${bridgeA_ip4:-198.18.10.10/24}"

bridgeB="${bridgeB:-bridgeB}"
bridgeB_ip4="${bridgeB_ip4:-198.18.11.10/24}"


test_description()
{
	cat - <<-EOT

	Bridges on physical interface and it's VLAN

	setup:

	   $nicA            -m-> $bridgeA
	     ^
	     +-l-  $vlanA   -m-> $bridgeB

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


	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${nicA}'
		VLAN_ID=${vlanA_id}
	EOF

	cat >"${dir}/ifcfg-${bridgeA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		BRIDGE=yes
		BRIDGE_PORTS=$nicA
		${bridgeA_ip4:+IPADDR='${bridgeA_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${bridgeB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		BRIDGE=yes
		BRIDGE_PORTS=$vlanA
		${bridgeB_ip4:+IPADDR='${bridgeB_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$nicA" "$vlanA" "$bridgeA" "$bridgeB"; do
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
	bold "=== step $step: ifup $nicA"

	echo "# wicked $wdebug ifup $cfg $nicA"
	wicked $wdebug ifup $cfg "$nicA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_down "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_down "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_down "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	bold "=== step $step: ifdown $bridgeA"

	echo "# wicked $wdebug ifdown $bridgeA"
	wicked $wdebug ifdown "$bridgeA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_down "$nicA"
	check_device_is_down "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_down "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	bold "=== step $step: ifup $vlanA"

	echo "# wicked $wdebug ifup $cfg $vlanA"
	wicked $wdebug ifup $cfg "$vlanA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_up "$vlanA"
	check_device_is_up "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	bold "=== step $step: ifdown $vlanA"

	echo "# wicked $wdebug ifdown $vlanA"
	wicked $wdebug ifdown "$vlanA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_up "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	bold "=== step $step: ifdown $bridgeA $bridgeB"

	echo "# wicked $wdebug ifdown $bridgeA $bridgeB"
	wicked $wdebug ifdown "$bridgeA" "$bridgeB"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_down "$nicA"
	check_device_is_down "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_down "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	bold "=== step $step: ifup $bridgeA"

	echo "# wicked $wdebug ifup $cfg $bridgeA"
	wicked $wdebug ifup $cfg "$bridgeA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_down "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	bold "=== step $step: ifdown $bridgeA"

	echo "# wicked $wdebug ifdown $bridgeA"
	wicked $wdebug ifdown "$bridgeA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_down "$nicA"
	check_device_is_down "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_down "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step9()
{
	bold "=== step $step: ifup $bridgeB"

	echo "# wicked $wdebug ifup $cfg $bridgeB"
	wicked $wdebug ifup $cfg "$bridgeB"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_up "$vlanA"
	check_device_is_up "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_all=step9

step10()
{
	bold "=== step $step: ifdown $bridgeA"

	echo "# wicked $wdebug ifdown $bridgeA"
	wicked $wdebug ifdown "$bridgeA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_down "$nicA"
	check_device_is_down "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_up "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	$ifup_all
}

step12()
{
	bold "=== step $step: ifdown $bridgeB"

	echo "# wicked $wdebug ifdown $bridgeB"
	wicked $wdebug ifdown "$bridgeB"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_down "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"

}

step13()
{
	$ifup_all
}

step14()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$bridgeA" "$bridgeB"
	echo ""

	check_device_is_down "$nicA"
	check_device_is_up "$bridgeA"
	check_device_is_down "$vlanA"
	check_device_is_up "$bridgeB"

	echo ""
	echo "=== step $step: finished with $err errors"

}


step99()
{
	bold "=== step $step: cleanup"

	for dev in "$nicA" "$vlanA" "$bridgeA" "$bridgeB" ; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown "$dev"
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
