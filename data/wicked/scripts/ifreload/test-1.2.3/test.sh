#!/bin/bash


dummyA="${dummyA:-dummyA}"
vlanA_id=${vlanA_id:-11}
vlanA="${vlanA:-vlan0.$vlanA_id}"
bridgeA="${bridgeA:-bridgeA}"
bridgeA_ip4="${bridgeA_ip4:-198.18.11.10/24}"


test_description()
{
	cat - <<-EOT

	Change config from bridge interface and run ifreload all.
	The port is a VLAN on a dummy interface.

	setup:

	   $dummyA <-l- $vlanA -m-> $bridgeA

	EOT
}

step0()
{
	print_test_description

	cat >"${dir}/ifcfg-$dummyA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		DUMMY=yes
	EOF

	cat >"${dir}/ifcfg-$vlanA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='$dummyA'
	EOF
}

step1()
{
	check_change_bridge_fwd_delay 7 "$vlanA"
}

step2()
{
	check_change_bridge_fwd_delay 5 "$vlanA"
}

step3()
{
	check_change_bridge_fwd_delay 10 "$vlanA"
}

step99()
{
	bold "=== $step: cleanup"

	echo "wicked $wdebug ifdown $bridgeA $vlanA $dummyA"
	wicked $wdebug ifdown "$bridgeA" "$vlanA" "$dummyA"
	echo ""

	rm -f "${dir}/ifcfg-$dummyA"
	rm -f "${dir}/ifcfg-$vlanA"
	rm -f "${dir}/ifcfg-$bridgeA"

	check_policy_not_exists "$dummyA"
	check_policy_not_exists "$bridgeA"
	check_device_is_down "$bridgeA"
}

. ../test-1.2/common.sh
