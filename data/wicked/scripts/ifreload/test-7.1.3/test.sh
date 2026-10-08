#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
vlanA_id=${vlanA_id:-11}
vlanB_id=${vlanB_id:-12}
bridgeA=${bridgeA:-bridgeA}
bridgeA_ip4="${bridgeA_ip4:-198.18.10.10/24}"
vlanA="${vlanA:-vlanA}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

test_description()
{

	cat - <<-EOT

	Change VLAN config (e.g. the VLAN_ID) and run ifreload all.
	The link is on top of a bridge interface.

	setup:
	   $nicA -m-> $bridgeA <-l- $vlanA

	EOT
}

step0()
{
	print_test_description

	cat >"${dir}/ifcfg-$nicA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$bridgeA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE=yes
		BRIDGE_PORTS='$nicA'
		IPADDR='$bridgeA_ip4'
	EOF

	cat >"${dir}/ifcfg-$vlanA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='$bridgeA'
		VLAN_ID='$vlanA_id'
		IPADDR='$vlanA_ip4'
	EOF

	log_device_config "$vlanA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$nicA"
	check_device_has_port "$bridgeA" "$nicA"
	check_device_has_link "$vlanA" "$bridgeA"
	check_vlan_id "$vlanA" "$vlanA_id"
}

step1()
{
	bold "=== $step: $vlanA / VLAN_ID=$vlanB_id / ifreload all"

	sed -i "/VLAN_ID=/c\VLAN_ID='$vlanB_id'" "${dir}/ifcfg-$vlanA"

	log_device_config "$vlanA" "$bridgeA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_has_link "$vlanA" "$bridgeA"
	check_vlan_id "$vlanA" "$vlanB_id"
}

step2()
{
	bold "=== $step: $vlanA / VLAN_ID=$vlanA_id / ifreload all"

	sed -i "/VLAN_ID=/c\VLAN_ID='$vlanA_id'" "${dir}/ifcfg-$vlanA"

	log_device_config "$vlanA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$nicA"
	check_device_is_up "$bridgeA"
	check_device_has_link "$vlanA" "$bridgeA"
	check_vlan_id "$vlanA" "$vlanA_id"
}


step99()
{
	bold "=== $step: cleanup"

	echo "wicked $wdebug ifdown  $vlanA $nicA $bridgeA"
	wicked $wdebug ifdown  "$vlanA" "$nicA" "$bridgeA"
	echo ""

	rm -f "${dir}/ifcfg-$nicA"
	rm -f "${dir}/ifcfg-$bridgeA"
	rm -f "${dir}/ifcfg-$vlanA"

	check_policy_not_exists "$nicA"
	check_policy_not_exists "$vlanA"
	check_policy_not_exists "$bridgeA"
}

. ../../lib/common.sh
