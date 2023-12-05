#!/bin/bash
#
# VLAN on virtual interface
#
# setup:
#
#    dummy0    <-l-    dummy0.11
#
# TODO: change vlan0 default name to dummy0.10

dummy0="${dummy0:-dummy0}"
dummy0_ip4="${dummy0_ip4:-198.18.4.1/24}"

vlan0_id="${vlan0_id:-10}"
#vlan0="${vlan0:-$dummy0.$vlan0_id}"
vlan0="${vlan0:-vlan$vlan0_id}"
vlan0_ip4="${vlan0_ip4:-198.18.2.1/24}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${dummy0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${dummy0_ip4:+IPADDR='${dummy0_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${vlan0_ip4:+IPADDR='${vlan0_ip4}'}
		ETHERDEVICE='${dummy0}'
		VLAN_ID='${vlan0_id}'
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' $BASH_SOURCE
		echo ""
		for dev in "$dummy0" "$vlan0" ; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup ${dummy0}"

	echo "# wicked $wdebug ifup $cfg ${dummy0}"
	wicked $wdebug ifup $cfg ${dummy0}
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_up "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown ${dummy0}"

	echo "# wicked $wdebug ifdown $dummy0"
	wicked $wdebug ifdown $dummy0
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_down "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	bold "=== step $step: ifup ${vlan0}"

	echo "# wicked $wdebug ifup $cfg ${vlan0}"
	wicked $wdebug ifup $cfg ${vlan0}
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_up "$dummy0"
	check_device_is_up "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_vlan0=step3

step4()
{
	bold "=== step $step: ifdown ${dummy0}"

	echo "# wicked $wdebug ifdown $dummy0"
	wicked $wdebug ifdown $dummy0
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_down "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	$ifup_vlan0
}

step6()
{
	bold "=== step $step: ifdown ${vlan0}"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown $vlan0
	echo ""

	print_device_status "$vlan0" "$dummy0"

	check_device_is_up "$dummy0"
	check_device_is_down "$vlan0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlan0" "$dummy0"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done

	echo ""
	echo "=== step $step: finished with $err errors"
}

. ../lib/common.sh
