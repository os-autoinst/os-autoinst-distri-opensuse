#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"
bridgeA="${bridgeA:-bridgeA}"
bondA="${bondA:-bondA}"
bondA_ip4="${bridgeA_ip4:-198.18.10.10/24}"
bondA_options="${bondA_options:-mode=active-backup miimon=100}"

test_description()
{
	cat - <<-EOT

	Change config from bridge interface and run ifreload all.
	The port is a bond with physical ports.

	setup:

	   $nicA,$nicB -m-> $bondA -m-> $bridgeA

	EOT
}

step0()
{
	print_test_description

	cat >"${dir}/ifcfg-$nicA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$nicB" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${bondA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bondA_options}'
		BONDING_SLAVE_1='$nicA'
		BONDING_SLAVE_2='$nicB'
	EOF
}

step1()
{
	check_change_bridge_fwd_delay 7 "$bondA"
}

step2()
{
	check_change_bridge_fwd_delay 5 "$bondA"
}

step3()
{
	check_change_bridge_fwd_delay 10 "$bondA"
}

step99()
{
	bold "=== $step: cleanup"

	echo "wicked $wdebug ifdown $bridgeA $bondA $nicA $nicB"
	wicked $wdebug ifdown "$bridgeA" "$bondA" "$nicA" "$nicB"
	echo ""

	rm -f "${dir}/ifcfg-$nicA"
	rm -f "${dir}/ifcfg-$nicB"
	rm -f "${dir}/ifcfg-$bondA"
	rm -f "${dir}/ifcfg-$bridgeA"

	check_policy_not_exists "$nicA"
	check_policy_not_exists "$nicB"
	check_policy_not_exists "$bondA"
	check_policy_not_exists "$bridgeA"
	check_device_is_down "$bridgeA"
}

. ../test-1.2/common.sh
