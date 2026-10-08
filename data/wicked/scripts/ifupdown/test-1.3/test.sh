#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
nicB="${nicB:?Missing "nicB" parameter, this should be set to the first physical ethernet adapter (e.g. nicB=eth2)}"

bondA="${bondA:-bondA}"
bondA_ip4="${bondA_ip4:-198.18.10.10/24}"

test_description()
{
	cat - <<-EOT

	Bond (master) on physical interfaces

	setup:

	   $nicA,$nicB   -m->    $bondA

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

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' $BASH_SOURCE
		echo ""
		for dev in "$nicA" "$nicB" "$bondA"; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $nicA"

	echo "# wicked $wdebug ifup $cfg $nicA"
	wicked $wdebug ifup $cfg $nicA
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA"

	check_device_is_up "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$bondA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $nicA $nicB $bondA"

	echo "# wicked $wdebug ifdown $nicA $nicB $bondA"
	wicked $wdebug ifdown "$nicA" "$nicB" "$bondA"
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_down "$bondA"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step2

step3()
{
	bold "=== step $step: ifup $nicB"

	echo "# wicked $wdebug ifup $cfg $nicB"
	wicked $wdebug ifup $cfg $nicB
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	$ifdown_all
}

step5()
{
	bold "=== step $step: ifup $bondA"

	echo "# wicked $wdebug ifup $cfg $bondA"
	wicked $wdebug ifup $cfg $bondA
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA"

	check_device_is_up "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_all=step5

step6()
{
	bold "=== step $step: down $nicA"

	echo "# wicked $wdebug ifdown $nicA"
	wicked $wdebug ifdown $nicA
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA"

	check_device_is_down "$nicA"
	check_device_is_up "$nicB"
	check_device_is_up "$bondA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	$ifup_all
}

step8()
{
	bold "=== step $step: down $nicB"

	echo "# wicked $wdebug ifdown $nicB"
	wicked $wdebug ifdown $nicB
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA"

	check_device_is_up "$nicA"
	check_device_is_down "$nicB"
	check_device_is_up "$bondA"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step9()
{
	$ifup_all
}

step10()
{
	bold "=== step $step: down $bondA"

	echo "# wicked $wdebug ifdown $bondA"
	wicked $wdebug ifdown $bondA
	echo ""

	print_device_status "$nicA" "$nicB" "$bondA"

	check_device_is_down "$nicA"
	check_device_is_down "$nicB"
	check_device_is_down "$bondA"

	echo ""
	echo "=== step $step: finished with $err errors"
}


step99()
{
	bold "=== step $step: cleanup"

	for dev in "$bondA" "$nicA" "$nicB"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
