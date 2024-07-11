#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
vlanA_id=${vlanA_id:-11}
vlanA="${vlanA:-vlan0.$vlanA_id}"
bridgeA="${bridgeA:-bridgeA}"
bridgeA_ip4="${bridgeA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT
	Change config from bridge interface and run ifreload all.
	The port is a VLAN on a physical interface.

	setup:

	    $nicA <-l- $vlanA -m-> $bridgeA

	EOT
}

step0()
{
	print_test_description

	cat >"${dir}/ifcfg-$nicA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$vlanA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='$nicA'
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

	echo "wicked $wdebug ifdown $bridgeA $vlanA $nicA"
	wicked $wdebug ifdown "$bridgeA" "$vlanA" "$nicA"
	echo ""

	rm -f "${dir}/ifcfg-$nicA"
	rm -f "${dir}/ifcfg-$vlanA"
	rm -f "${dir}/ifcfg-$bridgeA"

	check_policy_not_exists "$nicA"
	check_policy_not_exists "$bridgeA"
	check_device_is_down "$bridgeA"
}

. ../test-1.2/common.sh
