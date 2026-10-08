#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
bridgeA="${bridgeA:-bridgeA}"
bridgeA_ip4="${bridgeA_ip4:-198.18.10.10/24}"

test_description()
{
	cat - <<-EOT

	Change config from bridge interface and run ifreload all
	The port is a physical ethernet interface.

	setup:

	  $nicA -m-> $bridgeA

	EOT
}

step0()
{
	print_test_description
}

step1()
{
	check_change_bridge_fwd_delay 10 "$nicA"
}

step2()
{
	check_change_bridge_fwd_delay 5 "$nicA"
}

step3()
{
	check_change_bridge_fwd_delay 7 "$nicA"
}


step99()
{
	bold "=== $step: cleanup"

	echo "wicked $wdebug ifdown $bridgeA $nicA "
	wicked $wdebug ifdown "$bridgeA" "$nicA"
	echo ""

	rm -f "${dir}/ifcfg-$nicA"
	rm -f "${dir}/ifcfg-$bridgeA"

	check_policy_not_exists "$nicA"
	check_policy_not_exists "$bridgeA"
	check_device_is_down "$bridgeA"

}

. ../test-1.2/common.sh
