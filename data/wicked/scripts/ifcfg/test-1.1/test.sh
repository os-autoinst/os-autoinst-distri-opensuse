#!/bin/bash
#
# Check ifcfg-dummy* parsing
#


test_description()
{
	cat - <<-EOT

	Check ifcfg-dummy* config parsing.

	Examples:
	   * Valid vlan config (ETHERDEVICE=xxx) with the name dummy0.10 should
	     not be treated as dummy.
	   * ifcfg-dummy99 should be treated as dummy, also if DUMMY=yes is
	     not given.
	   * DUMMY=yes should be valid with any ifcfg-XXX name.
	   * A valid bridge config (BRIDGE=yes) with the config name ifcfg-dummy99 should
	     be treated as bridge and not as dummy.

	EOT
}

valid_dummy_by_name()
{
	local dummy=$1
	bold "=== step $step: $dummy"

	if device_exists "$dummy" || test -e "${dir}/ifcfg-$dummy"; then
		red "This test require interface name $dummy"
		((err++))
		return
	fi

	cat >"${dir}/ifcfg-$dummy" <<-EOF
		STARTMODE='auto'
	EOF

	log_device_config $dummy

	if wicked $wdebug show-config $cfg $dummy | grep '<dummy/>'; then
		echo "WORKS: $dummy was not treated as dummy interface"
	else
		red "ERROR: $dummy was treated as dummy!"
		((err++))
	fi

	echo "# wicked $wdebug ifup $cfg $dummy"
	wicked $wdebug ifup $cfg "$dummy"
	echo ""

	print_device_status "$dummy"
	check_device_is_up "$dummy"

	if [ "$dummy" != "dummy0" ]; then
		check_device_not_exists dummy0
	fi

	echo "# wicked $wdebug ifdown $dummy"
	wicked $wdebug ifdown "$dummy"
	echo ""
	rm "${dir}/ifcfg-$dummy"

	check_device_not_exists "$dummy"
	echo ""
	echo "=== step $step: finished with $err errors"
}

invalid_dummy_by_name()
{
	local dummy=$1
	bold "=== step $step: $dummy"

	if device_exists "$dummy" || test -e "${dir}/ifcfg-$dummy"; then
		red "This test require interface name $dummy"
		((err++))
		return
	fi

	cat >"${dir}/ifcfg-$dummy" <<-EOF
		STARTMODE='auto'
	EOF

	log_device_config $dummy

	if wicked $wdebug show-config $cfg "$dummy" | grep '<dummy/>'; then
		red "ERROR: $dummy was treated as dummy!"
		((err++))
		 wicked $wdebug show-config $cfg "$dummy"
	else
		echo "WORKS: $dummy was not treated as dummy interface"
	fi

	rm "${dir}/ifcfg-$dummy"

	echo ""
	echo "=== step $step: finished with $err errors"
}


step0()
{
	bold "=== $step -- Setup configuration"
}

step1()
{
	valid_dummy_by_name "dummy0"
}

step2()
{
	valid_dummy_by_name "dummy1"
}

step3()
{
	valid_dummy_by_name "dummy10"
}

step4()
{
	valid_dummy_by_name "dummy555"
}

step5()
{
	invalid_dummy_by_name "foobar"
}

step6()
{
	invalid_dummy_by_name "dummy1.10"
}

step7()
{
	invalid_dummy_by_name "dummybr0"
}

step8()
{
	invalid_dummy_by_name "dummy0bridge"
}

step9()
{
	invalid_dummy_by_name "dumm1"
}

step10()
{
	bold "=== step $step: foodo with DUMMY=yes"

	if device_exists "foodo" || test -e "${dir}/ifcfg-foodo"; then
		red "device 'foodo' exists but it shoud not!"
		((err++))
		return
	fi

	cat >"${dir}/ifcfg-foodo" <<-EOF
		STARTMODE='auto'
		DUMMY=yes
	EOF

	log_device_config foodo

	if wicked $wdebug show-config $cfg foodo | grep '<dummy/>'; then
		echo "WORKS: foodo was treated as dummy interface"
	else
		red "ERROR: foodo was not treated as dummy!"
		((err++))
	fi

	echo "# wicked $wdebug ifup $cfg foodo"
	wicked $wdebug ifup $cfg "foodo"
	echo ""

	print_device_status "foodo"
	check_device_is_up "foodo"

	check_device_not_exists dummy0

	echo "# wicked $wdebug ifdown foodo"
	wicked $wdebug ifdown "foodo"
	echo ""
	rm "${dir}/ifcfg-foodo"

	check_device_not_exists "foodo"
	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	bold "=== step $step: foodo with INTERFACETYPE=dummy (deprecated)"

	if device_exists "foodo" || test -e "${dir}/ifcfg-foodo"; then
		red "device 'foodo' exists but it shoud not!"
		((err++))
		return
	fi

	cat >"${dir}/ifcfg-foodo" <<-EOF
		STARTMODE='auto'
		INTERFACETYPE=dummy
	EOF

	log_device_config foodo

	if wicked $wdebug show-config $cfg foodo | grep '<dummy/>'; then
		echo "WORKS: foodo was treated as dummy interface"
	else
		red "ERROR: foodo was not treated as dummy!"
		((err++))
	fi

	echo "# wicked $wdebug ifup $cfg foodo"
	wicked $wdebug ifup $cfg "foodo"
	echo ""

	print_device_status "foodo"
	check_device_is_up "foodo"

	check_device_not_exists dummy0

	echo "# wicked $wdebug ifdown foodo"
	wicked $wdebug ifdown "foodo"
	echo ""
	rm "${dir}/ifcfg-foodo"

	check_device_not_exists "foodo"
	echo ""
	echo "=== step $step: finished with $err errors"
}


step12()
{
	bold "=== step $step: ifcfg-dummy10.10"

	if device_exists "dummy10.10" || test -e "${dir}/ifcfg-dummy10.10"; then
		red "Device dummy10.10 exists, but it shoud not to run this test."
		((err++))
		return
	fi

	cat >"${dir}/ifcfg-dummy10.10" <<-EOF
		STARTMODE='auto'
		ETHERDEVICE=dummy10
	EOF

	log_device_config dummy10.10 dummy10

	if wicked $wdebug show-config $cfg dummy10.10 | grep '<vlan>'; then
		echo "WORKS: ifcfg-dummy10.10 was treated as vlan interface"
	else
		red "ERROR: ifcfg-dummy10.10 was not treated as vlan!"
		((err++))
	fi

	echo "# wicked $wdebug ifup $cfg dummy10.10"
	wicked $wdebug ifup $cfg "dummy10.10"
	echo ""

	print_device_status "dummy10.10"
	check_device_is_up "dummy10.10"

	check_device_exists dummy10
	check_device_exists dummy10.10

	echo "# wicked $wdebug ifdown dummy10.10"
	wicked $wdebug ifdown "dummy10.10"
	echo ""
	rm "${dir}/ifcfg-dummy10.10"

	check_device_exists "dummy10"
	check_device_not_exists "dummy10.10"

	echo "# wicked $wdebug ifdown dummy10"
	wicked $wdebug ifdown "dummy10"
	echo ""
	check_device_not_exists "dummy10.10"
	check_device_not_exists "dummy10"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step13()
{
	bold "=== step $step: dummy555 as bridge"

	if device_exists "dummy555" || test -e "${dir}/ifcfg-dummy555"; then
		red "device 'dummy555' exists but it shoud not!"
		((err++))
		return
	fi

	cat >"${dir}/ifcfg-dummy555" <<-EOF
		STARTMODE='auto'
		BRIDGE=yes
	EOF

	log_device_config dummy555

	if wicked $wdebug show-config $cfg dummy555 | grep '<bridge'; then
		echo "WORKS: dummy555 was treated as bridge interface"
	else
		red "ERROR: dummy555 was not treated as bridge!"
		((err++))
	fi

	rm "${dir}/ifcfg-dummy555"

	echo ""
	echo "=== step $step: finished with $err errors"
}


step99()
{
	bold "=== step $step: cleanup"

	echo ""
	echo "=== step $step: finished with $err errors"
}

. ../../lib/common.sh
