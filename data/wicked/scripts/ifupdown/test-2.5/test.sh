#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"

teamA="${teamA:-teamA}"
teamA_ip4="${teamA_ip4:-198.18.10.10/24}"

vlanA_id=10
vlanA="${vlanA:-$teamA.$vlanA_id}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT
	VLAN on Team of physical interfaces

	setup:

	    $nicA,$nicB   -m->    $teamA   <-l-    $vlanA

	EOT
}

step0()
{
	bold "=== $step -- Setup configuration"

	print_test_description

	cat >"${dir}/ifcfg-${nicA}" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${nicB}" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${teamA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${teamA_ip4:+IPADDR='${teamA_ip4}'}
		TEAM_RUNNER=activebackup
		TEAM_PORT_DEVICE_1="$nicA"
		TEAM_PORT_DEVICE_2="$nicB"
	EOF

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${teamA}'
		VLAN_ID=${vlanA_id}
		${vlanA_ip4:+IPADDR='${vlanA_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$nicA" "$nicB" "$teamA" "$vlanA"; do
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

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_up "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$teamA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$teamA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	bold "=== step $step: ifdown $teamA"

	echo "# wicked $wdebug ifdown $teamA"
	wicked $wdebug ifdown "$teamA"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_down "$teamA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step3

step4()
{
	bold "=== step $step: ifup $nicB"

	echo "# wicked $wdebug ifup $cfg $nicB"
	wicked $wdebug ifup $cfg "$nicB"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$teamA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_down "$nicA"
	check_device_is_up "$teamA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	$ifdown_all
}

step7()
{
	bold "=== step $step: ifup $teamA"

	echo "# wicked $wdebug ifup $cfg $teamA"
	wicked $wdebug ifup $cfg "$teamA"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_up "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$teamA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	$ifdown_all
}

step9()
{
	bold "=== step $step: ifup $vlanA"

	echo "# wicked $wdebug ifup $cfg $vlanA"
	wicked $wdebug ifup $cfg "$vlanA"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_up "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$teamA"
	check_device_is_up "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$teamA"
	check_device_is_up "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	bold "=== step $step: ifdown $nicB"

	echo "# wicked $wdebug ifdown $nicB"
	wicked $wdebug ifdown "$nicB"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$teamA"
	check_device_is_up "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step12()
{
	bold "=== step $step: ifdown $vlanA"

	echo "# wicked $wdebug ifdown $vlanA"
	wicked $wdebug ifdown "$vlanA"
	echo ""

	print_device_status "$nicA" "$nicB" "$teamA" "$vlanA"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$teamA"
	check_device_is_down "$vlanA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlanA" "$nicA" "$nicB" "$teamA"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
