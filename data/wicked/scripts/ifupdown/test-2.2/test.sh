#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicA_ip4=${nicA_ip4:-198.18.10.10/24}

vlanA_id=10
vlanA="${vlanA:-$nicA.$vlanA_id}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

vlanB_id=20
vlanB="${vlanB:-$nicA.$vlanB_id}"
vlanB_ip4="${vlanB_ip4:-198.18.12.10/24}"

macvlanA="${macvlanA:-macvlanA}"
macvlan0_ip4="${macvlan0_ip4:-198.18.10.101/24}"

macvlanB="${macvlanB:-macvlanB}"
macvlan1_ip4="${macvlan1_ip4:-198.18.10.102/24}"

test_description()
{
	cat - <<-EOT
	MACVLANs on top of VLANs on same physical interface

	- nicA is not created or deleted by wicked on shutdown
	- nicA.* vlans are created and deleted by wicked/kernel on shutdown
	- macvlan* are created and deleted by wicked/kernel on shutdown (of nicA.*)


	setup:

	    $nicA  <-l-  $vlanA  <-l-  $macvlanA
		   <-l-  $vlanB  <-l-  $macvlanB
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

	cat >"${dir}/ifcfg-${vlanB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${nicA}'
		VLAN_ID=${vlanB_id}
		${vlanB_ip4:+IPADDR='${vlanB_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${macvlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		MACVLAN_DEVICE='${vlanA}'
		${macvlan0_ip4:+IPADDR='${macvlan0_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${macvlanB}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		MACVLAN_DEVICE='${vlanB}'
		${macvlan1_ip4:+IPADDR='${macvlan1_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"; do
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
	wicked $wdebug ifup $cfg $nicA
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown $nicA
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_down "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step2

step3()
{
	bold "=== step $step: ifup $vlanA"

	echo "# wicked $wdebug ifup $cfg $vlanA"
	wicked $wdebug ifup $cfg "$vlanA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_up "$vlanA"
	check_device_is_down "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	bold "=== step $step: ifdown $vlanA"

	echo "# wicked $wdebug ifdown $vlanA"
	wicked $wdebug ifdown "$vlanA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	$ifdown_all
}


step6()
{
	bold "=== step $step: ifup $vlanB"

	echo "# wicked $wdebug ifup $cfg $vlanB"
	wicked $wdebug ifup $cfg "$vlanB"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_up "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	bold "=== step $step: ifdown $vlanB"

	echo "# wicked $wdebug ifdown $vlanB"
	wicked $wdebug ifdown "$vlanB"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_down "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	$ifdown_all
}

step9()
{
	bold "=== step $step: ifup $macvlanA"

	echo "# wicked $wdebug ifup $cfg $macvlanA"
	wicked $wdebug ifup $cfg "$macvlanA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_up "$vlanA"
	check_device_is_down "$vlanB"
	check_device_is_up "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	bold "=== step $step: ifdown $macvlanA"

	echo "# wicked $wdebug ifdown $macvlanA"
	wicked $wdebug ifdown "$macvlanA"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_up "$vlanA"
	check_device_is_down "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	$ifdown_all
}

step12()
{
	bold "=== step $step: ifup $macvlanB"

	echo "# wicked $wdebug ifup $cfg $macvlanB"
	wicked $wdebug ifup $cfg "$macvlanB"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_up "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_up "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step13()
{
	bold "=== step $step: ifdown $macvlanB"

	echo "# wicked $wdebug ifdown $macvlanB"
	wicked $wdebug ifdown "$macvlanB"
	echo ""

	print_device_status "$nicA" "$vlanA" "$vlanB" "$macvlanA" "$macvlanB"

	check_device_is_up "$nicA"
	check_device_is_down "$vlanA"
	check_device_is_up "$vlanB"
	check_device_is_down "$macvlanA"
	check_device_is_down "$macvlanB"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$macvlanB" "$macvlanA" "$vlanB" "$vlanA" "$nicA"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
