#!/bin/bash


dummyA="${dummyA:-dummyA}"
vlanA_id=${vlanA_id:-11}
vlanB_id=${vlanB_id:-12}
vlanA="${vlanA:-vlanA}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT

	Change VLAN config (e.g. the VLAN_ID) and run ifreload all.
	The link is on top of a dummy interface.

	setup:

	   $dummyA <-l- $vlanA

	EOT
}

check_change_vlan_id()
{
	local vlan=$1; shift
	local vlan_id=$1; shift

	sed -i "/VLAN_ID=/c\VLAN_ID='$vlan_id'" "${dir}/ifcfg-$vlan"

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
		BOOTPROTO='static'
		ETHERDEVICE='$dummyA'
		VLAN_ID='$vlanA_id'
		IPADDR='$vlanA_ip4'
	EOF

	log_device_config "$vlanA" "$dummyA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$dummyA"
	check_device_has_link "$vlanA" "$dummyA"
	check_vlan_id "$vlanA" "$vlanA_id"
}



step1()
{
	bold "=== $step: $vlan / VLAN_ID=$vlanB_id / ifreload all"

	sed -i "/VLAN_ID=/c\VLAN_ID='$vlanB_id'" "${dir}/ifcfg-$vlanA"

	log_device_config "$vlanA" "$dummyA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$dummyA"
	check_device_has_link "$vlanA" "$dummyA"
	check_vlan_id "$vlanA" "$vlanB_id"
}

step2()
{
	bold "=== $step: $vlan / VLAN_ID=$vlanA_id / ifreload all"

	sed -i "/VLAN_ID=/c\VLAN_ID='$vlanA_id'" "${dir}/ifcfg-$vlanA"

	log_device_config "$vlanA" "$dummyA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$dummyA"
	check_device_has_link "$vlanA" "$dummyA"
	check_vlan_id "$vlanA" "$vlanA_id"
}


step99()
{
	bold "=== $step: cleanup"

	echo "wicked $wdebug ifdown  $vlanA $dummyA"
	wicked $wdebug ifdown  "$vlanA" "$dummyA"
	echo ""

	rm -f "${dir}/ifcfg-$dummyA"
	rm -f "${dir}/ifcfg-$vlanA"

	check_policy_not_exists "$dummyA"
	check_policy_not_exists "$vlanA"
}

. ../../lib/common.sh
