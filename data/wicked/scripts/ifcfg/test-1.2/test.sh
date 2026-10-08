#!/bin/bash


test_description()
{
	cat - <<-EOT

	Infiniband configuration parsing checks.
	  * see: https://gitlab.suse.de/wicked-maintainers/wicked/-/wikis/infiniband-names
	  * Check ^ifcfg-ib[0-9]+(.[0-9A-Fa-f]+)?$ parsing checks

	EOT
}


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"

check_wicked_xml_is_infiniband_child()
{
	local ifc=$1

	if wicked $wdebug show-config $cfg $ifc | wicked xpath --reference 'interface/infiniband:child' ''; then
		echo "WORKS: ifcfg-$ifc was treated as infiniband:child interface"
	else
		red "ERROR: ifcfg-$ifc was not treated as infiniband:child interface!"
		((err++))
	fi
	check_wicked_xml_is_not_infiniband "$ifc"
}

check_wicked_xml_is_not_infiniband_child()
{
	local ifc=$1

	if ! wicked $wdebug show-config $cfg "$ifc" | wicked xpath --reference 'interface/infiniband:child' '' 2>/dev/null ; then
		echo "WORKS: ifcfg-$ifc was not treated as infiniband:child interface"
	else
		red "ERROR: ifcfg-$ifc was treated as infiniband:child interface!"
		((err++))
	fi
}


check_wicked_xml_is_infiniband()
{
	local ifc=$1

	if wicked $wdebug show-config $cfg "$ifc" | wicked xpath --reference 'interface/infiniband' ''; then
		echo "WORKS: ifcfg-$ifc was treated as infiniband interface"
	else
		red "ERROR: ifcfg-$ifc was not treated as infiniband interface!"
		((err++))
	fi
	check_wicked_xml_is_not_infiniband_child "$ifc"
}

check_wicked_xml_is_not_infiniband()
{
	local ifc=$1

	if ! wicked $wdebug show-config $cfg "$ifc" | wicked xpath --reference 'interface/infiniband' '' 2>/dev/null ; then
		echo "WORKS: ifcfg-$ifc was not treated as infiniband interface"
	else
		red "ERROR: ifcfg-$ifc was treated as infiniband interface!"
		((err++))
	fi
}

check_wicked_xml_is_ipoib_pkey()
{
	local ifc=$1
  	local pkey=$2
	val=$(wicked show-config $ifc | tee $step-config.xml | wicked xpath --reference interface/infiniband:child '%{pkey}')
	if [ $? -ne 0 ]; then
		red "ERROR: ifcfg-$ifc does not have interface/infiniband/pkey value!"
		((err++))
        else
		if [ "$val" == "$pkey" ]; then
			echo "WORKS: ifcfg-$ifc has IPOIB_PKEY=$pkey";
		else
			red "ERROR: ifcfg-$ifc wrong PKEY expect:$pkey got:$val"
			((err++))
		fi
	fi
}

check_wicked_xml_is_ipoib_device()
{
	local ifc=$1
  	local device=$2
	val=$(wicked show-config $ifc | wicked xpath --reference interface/infiniband:child '%{device}')
	if [ $? -ne 0 ]; then
		red "ERROR: ifcfg-$ifc does not have interface/infiniband/device value!"
		((err++))
        else
		if [ "$val" == "$device" ]; then
			echo "WORKS: ifcfg-$ifc has IPOIB_DEVICE=$device";
		else
			red "ERROR: ifcfg-$ifc wrong IPOIB_DEVICE expect:'$device' got:'$val'"
			((err++))
		fi
	fi
}

check_wicked_xml_is_vlan()
{
	local ifc=$1
  	local device=$2
	local tag=$3

	val=$(wicked show-config "$ifc" | wicked xpath --reference "interface/vlan" '%{device}/%{tag}')
	if [ $? -ne 0 ]; then
		red "ERROR: ifcfg-$ifc does not have interface/vlan value!"
		((err++))
        else
		if [ "$val" == "$device/$tag" ]; then
			echo "WORKS: ifcfg-$ifc has device=$device tag:$tag";
		else
			red "ERROR: ifcfg-$ifc wrong vlan config expect:'$device/$tag' got:'$val'"
			((err++))
		fi
	fi
}

check_wicked_xml_is_dummy()
{
	local ifc=$1

	if ! wicked show-config "$ifc" | wicked xpath --reference "interface/dummy" '' >/dev/null 2>&1; then
		red "ERROR: ifcfg-$ifc does not have interface/dummy value!"
		((err++))
        else
		echo "WORKS: ifcfg-$ifc is dummy config"
	fi
}

check_wicked_xml_is_bridge()
{
	local ifc=$1

	if ! wicked show-config "$ifc" | wicked xpath --reference "interface/bridge" '' >/dev/null 2>&1; then
		red "ERROR: ifcfg-$ifc does not have interface/bridge value!"
		((err++))
        else
		echo "WORKS: ifcfg-$ifc is bridge config"
	fi
}

valid_ib_config()
{
	local name="$1"
	local device="$2"
	local pkey="$3"

	bold "=== step $step: valid infiniband $name ${device:+DEVICE=$device} ${pkey:+PKEY=$pkey}"

	if [ -n "$device" ] && [ -z "$pkey" ]; then
		red "FATAL: missing PKEY parameter!"
		exit 2
	fi

	if test -e ${dir}/ifcfg-$name; then
		red "ERROR: we expect a system without ${dir}/ifcfg-$name config!"
		((err++))
		return
	fi

	cat - > "${dir}/ifcfg-$name"

	log_device_config "$name"

	if [[ -n "$device" ]]; then
		check_wicked_xml_is_infiniband_child "$name"
	        check_wicked_xml_is_ipoib_pkey "$name" "$pkey"
		check_wicked_xml_is_ipoib_device "$name" "$device"
	else
		check_wicked_xml_is_infiniband "$name"
	fi

	rm "${dir}/ifcfg-$name"

	echo ""
	echo "=== step $step: finished with $err errors"
}

invalid_ib_config()
{
	local name="$1"
	local warning="$2"
	local out

	bold "=== step $step: invalid infiniband $name ${warning:+warning=~/$warning/}"

	if test -e "${dir}/ifcfg-$name"; then
		red "ERROR: we expect a system without ${dir}/ifcfg-$name config!"
		((err++))
		return
	fi

	cat - > "${dir}/ifcfg-$name"

	log_device_config "$name"

	check_wicked_xml_is_not_infiniband "$name"
	check_wicked_xml_is_not_infiniband_child "$name"

	out="$(wicked show-config "$name" 2>/dev/null)"
	if [ -n "$warning" ] && [ -n "$out" ]; then
		red "ERROR: expect no config output on STDOUT with invalid infiniband"
		red "Got: $out"
		((err++))
	fi

	out="$(wicked show-config "$name" 2>&1)"
	if ! [[ "$out" =~ $warning ]]; then
		red "ERROR: missing warning -- exp:$warning got:$out"
		((err++))
	else
		echo "WORKS: wicked show-config $name has output on STDERR matching /$warning/"
		echo "      $out"
	fi


	rm "${dir}/ifcfg-$name"

	echo ""
	echo "=== step $step: finished with $err errors"
}

valid_vlan_config()
{
	local name="$1"
	local parent="$2"
	local tag="$3"

	bold "=== step $step: valid vlan $name "

	if test -e ${dir}/ifcfg-$name; then
		red "ERROR: we expect a system without ${dir}/ifcfg-$name config!"
		((err++))
		return
	fi

	if test -e ${dir}/ifcfg-$parent; then
		red "ERROR: we expect a system without ${dir}/ifcfg-$parent config!"
		((err++))
		return
	fi

	cat > "${dir}/ifcfg-$parent" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	EOT

	cat - > "${dir}/ifcfg-$name"

	log_device_config "$name"

	tmpfile=$(mktemp)
	wicked show-config "$name" 2>"$tmpfile" 1>/dev/null

	if [ -n "$(cat "$tmpfile")" ]; then
		red "ERROR: 'wicked show-config $name' prints something on STDERR"
		red "      $(cat "$tmpfile")"
		((err++))
	fi
	rm "$tmpfile"

	check_wicked_xml_is_not_infiniband "$name"
	check_wicked_xml_is_not_infiniband_child "$name"
	check_wicked_xml_is_vlan "$name" "$parent" "$tag"

	rm "${dir}/ifcfg-$name"
	rm "${dir}/ifcfg-$parent"

	echo ""
	echo "=== step $step: finished with $err errors"
}

valid_dummy_config()
{
	local name="$1"

	bold "=== step $step: valid dummy $name "

	if test -e "${dir}/ifcfg-$name"; then
		red "ERROR: we expect a system without ${dir}/ifcfg-$name config!"
		((err++))
		return
	fi

	cat - > "${dir}/ifcfg-$name"

	log_device_config "$name"

	tmpfile=$(mktemp)
	wicked show-config "$name" 2>"$tmpfile" 1>/dev/null

	if [ -n "$(cat "$tmpfile")" ]; then
		red "ERROR: 'wicked show-config $name' prints something on STDERR"
		red "      $(cat "$tmpfile")"
		((err++))
	fi
	rm "$tmpfile"

	check_wicked_xml_is_not_infiniband "$name"
	check_wicked_xml_is_not_infiniband_child "$name"
	check_wicked_xml_is_dummy "$name"

	rm "${dir}/ifcfg-$name"

	echo ""
	echo "=== step $step: finished with $err errors"
}

valid_bridge_config()
{
	local name="$1"

	bold "=== step $step: valid bridge $name "

	if test -e "${dir}/ifcfg-$name"; then
		red "ERROR: we expect a system without ${dir}/ifcfg-$name config!"
		((err++))
		return
	fi

	cat - > "${dir}/ifcfg-$name"

	log_device_config "$name"

	tmpfile=$(mktemp)
	wicked show-config "$name" 2>"$tmpfile" 1>/dev/null

	if [ -n "$(cat "$tmpfile")" ]; then
		red "ERROR: 'wicked show-config $name' prints something on STDERR"
		red "      $(cat "$tmpfile")"
		((err++))
	fi
	rm "$tmpfile"

	check_wicked_xml_is_not_infiniband "$name"
	check_wicked_xml_is_not_infiniband_child "$name"
	check_wicked_xml_is_bridge "$name"

	rm "${dir}/ifcfg-$name"

	echo ""
	echo "=== step $step: finished with $err errors"
}


step0()
{
	bold "=== $step -- Setup configuration"
}

step1()
{
	valid_ib_config "ib0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	EOT
}

step2()
{
	invalid_ib_config "ib0" "Missing.+IPOIB_DEVICE" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	EOT
}

step3()
{
	valid_ib_config "ib0" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	EOT
}

step4()
{
	invalid_ib_config "ib0" "Missing.+IPOIB_PKEY" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	EOT
}

step5()
{
	valid_ib_config "ib0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step6()
{
	invalid_ib_config "ib0" "Missing.+IPOIB_DEVICE" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step7()
{
	valid_ib_config "ib0" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step8()
{
	invalid_ib_config "ib0" "Missing.+IPOIB_PKEY" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step9()
{
	valid_ib_config "ib0.8001" "ib0" "0x8001" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	EOT
}

step10()
{
	valid_ib_config "ib0.8001" "ib0" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	EOT
}

step11()
{
	valid_ib_config "ib0.8001" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	EOT
}

step12()
{
	valid_ib_config "ib0.8001" "ib5" "0x8001" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	EOT
}

step13()
{
	valid_ib_config "ib0.8001" "ib0" "0x8001"<<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step14()
{
	valid_ib_config "ib0.8001" "ib0" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step15()
{
	valid_ib_config "ib0.8001" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step16()
{
	valid_ib_config "ib0.8001" "ib5" "0x8001" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

# ----
step17()
{
	invalid_ib_config "ib0.1" "not in supported range"<<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	EOT
}

step18()
{
	valid_ib_config "ib0.1" "ib0" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	EOT
}

step19()
{
	valid_ib_config "ib0.1" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	EOT
}

step20()
{
	invalid_ib_config "ib0.1" "not in supported range" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	EOT
}

step21()
{
	invalid_ib_config "ib0.1" "not in supported range" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step22()
{
	valid_ib_config "ib0.1" "ib0" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step23()
{
	valid_ib_config "ib0.1" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step24()
{
	invalid_ib_config "ib0.1" "not in supported range" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

#------------

step25()
{
	valid_vlan_config "foo" "$nicA" "10"<<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step26()
{
	valid_vlan_config "foo" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step27()
{
	valid_vlan_config "foo" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step28()
{
	valid_vlan_config "foo" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT

}

step29()
{
	valid_ib_config "foo" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step30()
{
	invalid_ib_config "foo" "Missing.*IPOIB_DEVICE" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step31()
{
	valid_ib_config "foo" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step32()
{
	invalid_ib_config "foo" "Missing.*IPOIB_PKEY" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

#----

step33()
{
	valid_vlan_config "foo.8001" "$nicA" "10"<<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step34()
{
	valid_vlan_config "foo.8001" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step35()
{
	valid_vlan_config "foo.8001" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step36()
{
	valid_vlan_config "foo.8001" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT

}

step37()
{
	valid_ib_config "foo.8001" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step38()
{
	invalid_ib_config "foo.8001" "Missing.*IPOIB_DEVICE" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step39()
{
	valid_ib_config "foo.8001" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step40()
{
	invalid_ib_config "foo.8001" "Missing.*IPOIB_PKEY" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

#---

step41()
{
	valid_vlan_config "foo.bar" "$nicA" "10"<<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step42()
{
	valid_vlan_config "foo.bar" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step43()
{
	valid_vlan_config "foo.bar" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step44()
{
	valid_vlan_config "foo.bar" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT

}

step45()
{
	valid_ib_config "foo.bar" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step46()
{
	invalid_ib_config "foo.bar" "Missing.*IPOIB_DEVICE" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step47()
{
	valid_ib_config "foo.bar" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step48()
{
	invalid_ib_config "foo.bar" "Missing.*IPOIB_PKEY" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

#---

step49()
{
	valid_dummy_config "dummy0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	EOT
}

step50()
{
	valid_dummy_config "dummy0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	EOT
}

step51()
{
	valid_dummy_config "dummy0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	EOT
}

step52()
{
	valid_dummy_config "dummy0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	EOT

}

step53()
{
	valid_ib_config "dummy0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step54()
{
	valid_ib_config "dummy0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_MODE="connected"
	EOT
}

step55()
{
	valid_ib_config "dummy0" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_UMCAST="allowed"
	EOT
}


step56()
{
	invalid_ib_config "dummy0" "Missing.*IPOIB_DEVICE" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step57()
{
	valid_ib_config "dummy0" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step58()
{
	invalid_ib_config "dummy0" "Missing.*IPOIB_PKEY" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

#----

step59()
{
	valid_vlan_config "ib.8001" "$nicA" "10"<<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step60()
{
	valid_vlan_config "ib.8001" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step61()
{
	valid_vlan_config "ib.8001" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step62()
{
	valid_vlan_config "ib.8001" "$nicA" "10" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT

}

step63()
{
	valid_ib_config "ib.8001" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB=yes
	EOT
}

step64()
{
	invalid_ib_config "ib.8001" "Missing.*IPOIB_DEVICE" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB=yes
	EOT
}

step65()
{
	valid_ib_config "ib.8001" "ib5" "0x8005" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_PKEY=8005
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

step66()
{
	invalid_ib_config "ib.8001" "Missing.*IPOIB_PKEY" <<-EOT
	STARTMODE='auto'
	BOOTPROTO='none'
	IPOIB_DEVICE=ib5
	IPOIB=yes
	EOT
}

#----

step67()
{
	valid_vlan_config "ib0" "$nicA" "0" <<-EOT
	ETHERDEVICE=$nicA
	EOT
}

step68()
{
	valid_vlan_config "ib0" "$nicA" "10" <<-EOT
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step69()
{
	valid_vlan_config "ib0.1" "$nicA" "1" <<-EOT
	ETHERDEVICE=$nicA
	EOT
}

step70()
{
	valid_vlan_config "ib0.1" "$nicA" "10" <<-EOT
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step71()
{
	valid_vlan_config "foo.4001" "$nicA" "4001" <<-EOT
	ETHERDEVICE=$nicA
	EOT
}

step72()
{
	valid_vlan_config "foo.4001" "$nicA" "10" <<-EOT
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step73()
{
	invalid_ib_config "foo.8001" "VLAN tag .* is out of .* range" <<-EOT
	ETHERDEVICE=$nicA
	EOT
}

step74()
{
	valid_vlan_config "foo.8001" "$nicA" "10" <<-EOT
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step75()
{
	invalid_ib_config "foo.bar" "Cannot parse vlan-tag" <<-EOT
	ETHERDEVICE=$nicA
	EOT
}

step76()
{
	valid_vlan_config "foo.bar" "$nicA" "10" <<-EOT
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}

step77()
{
	invalid_ib_config "ib0.8001" "VLAN tag .* is out of .* range" <<-EOT
	ETHERDEVICE=$nicA
	EOT
}

step78()
{
	valid_vlan_config "ib0.8001" "$nicA" "10" <<-EOT
	ETHERDEVICE=$nicA
	VLAN_ID=10
	EOT
}


step79()
{
	valid_bridge_config "ib0" <<-EOT
	BRIDGE=yes
	BRIDGE_PORTS="$nicA"
	EOT
}

step80()
{
	valid_bridge_config "ib0.8001" <<-EOT
	BRIDGE=yes
	BRIDGE_PORTS="$nicA"
	EOT
}

step81()
{
	valid_bridge_config "foo.8001" <<-EOT
	BRIDGE=yes
	BRIDGE_PORTS="$nicA"
	EOT
}

step82()
{
	valid_bridge_config "foo.bar" <<-EOT
	BRIDGE=yes
	BRIDGE_PORTS="$nicA"
	EOT
}

step99()
{
	bold "=== step $step: cleanup"

	echo ""
	echo "=== step $step: finished with $err errors"
}

. ../../lib/common.sh
