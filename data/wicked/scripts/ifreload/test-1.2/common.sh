#!/bin/bash

check_change_bridge_fwd_delay()
{
	fwd_delay=$1; shift
	bold "=== $step: br {$*} / BRIDGE_FORWARDDELAY=$fwd_delay / ifreload all"

	if [ "$with_port_config" == "yes" ];then
		for dev in "$@"; do
			test -e "${dir}/ifcfg-$dev" && continue
			cat >"${dir}/ifcfg-$dev" <<-EOF
				STARTMODE='auto'
				BOOTPROTO='none'
			EOF

		done
	fi

	# change bridge to use $dummy1 instead + ifreload
	cat >"${dir}/ifcfg-$bridgeA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$*'
		BRIDGE_FORWARDDELAY=$fwd_delay
		IPADDR=${bridgeA_ip4}
	EOF

	log_device_config "$@" "$bridgeA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_has_port "$bridgeA" "$@"
	check_device_is_up "$bridgeA"

	fwd_delay_xml=$(wicked show-config bridgeA | wicked xpath --reference 'interface/bridge' '%{forward-delay}');
	fwd_delay="$(printf "%.2f" "$fwd_delay")"
	if [ "$fwd_delay_xml" == "$fwd_delay" ]; then
		echo "WORKS: forward-delay is $fwd_delay_xml"
	else
		red "ERROR: forward-delay is wrong, exp:$fwd_delay got:$fwd_delay_xml"
		((err++))
	fi
}



. ../../lib/common.sh
