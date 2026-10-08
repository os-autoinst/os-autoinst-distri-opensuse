#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"

bondA="${bondA:-bondA}"
bondA_ip4="${bondA_ip4:-198.18.10.10/24}"

vlanA_id=11
vlanA="${vlanA:-$bondA.$vlanA_id}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

vlanB_id=12
vlanB="${vlanB:-$bondA.$vlanB_id}"
vlanB_ip4="${vlanB_ip4:-198.18.12.10/24}"

test_description()
{
	cat - <<-EOT

	VLAN on Bond of physical interfaces

	setup:

	   $nicA,$nicB   -m->    $bondA   <-l-    $vlanA
				          <-l-    $vlanB

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

	cat >"${dir}/ifcfg-${bondA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${bondA_ip4:+IPADDR='${bondA_ip4}'}
		BONDING_MASTER=yes
		BONDING_MODULE_OPTS='mode=active-backup miimon=100'
		BONDING_SLAVE_0="$nicA"
		BONDING_SLAVE_1="$nicB"
	EOF

	cat >"${dir}/ifcfg-${vlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${bondA}'
		VLAN_ID=${vlanA_id}
		${vlanA_ip4:+IPADDR='${vlanA_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${vlanB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${bondA}'
		VLAN_ID=${vlanB_id}
		${vlanB_ip4:+IPADDR='${vlanB_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"; do
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

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_up "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	bold "=== step $step: ifdown $bondA"

	echo "# wicked $wdebug ifdown $bondA"
	wicked $wdebug ifdown "$bondA"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_down "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

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

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_down "$nicA"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	$ifdown_all
}

step7()
{
	bold "=== step $step: ifup $bondA"

	echo "# wicked $wdebug ifup $cfg $bondA"
	wicked $wdebug ifup $cfg "$bondA"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_up "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

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

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_up "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"
	check_device_is_up "$vlanA"
	check_device_is_down "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	bold "=== step $step: ifup $vlanB"

	echo "# wicked $wdebug ifup $cfg $vlanB"
	wicked $wdebug ifup $cfg "$vlanB"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_up "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"
	check_device_is_up "$vlanA"
	check_device_is_up "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown "$nicA"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"
	check_device_is_up "$vlanA"
	check_device_is_up "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step12()
{
	bold "=== step $step: ifdown $vlanA"

	echo "# wicked $wdebug ifdown $vlanA"
	wicked $wdebug ifdown "$vlanA"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_up "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step13()
{
	bold "=== step $step: ifdown $vlanB"

	echo "# wicked $wdebug ifdown $vlanB"
	wicked $wdebug ifdown "$vlanB"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step14()
{
	bold "=== step $step: ifdown $nicB"

	echo "# wicked $wdebug ifdown $nicB"
	wicked $wdebug ifdown "$nicB"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA" "$vlanA" "$vlanB"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$bondA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step15()
{
	$ifdown_all
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlanB" "$vlanA" "$nicA" "$nicB" "$bondA"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
