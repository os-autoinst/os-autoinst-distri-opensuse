#!/bin/bash

pause()
{
	test "X$pause" = X && return
	echo -n "Press enter to continue...."
	read
}

show_bridge()
{
	br=$1
	echo -n "bridge:$br {"
	bridge link | grep "master $br" | awk -F': ' '{print $2}' | xargs echo -n
	echo "}"
}

show_all_bridges()
{
        for br in $(ip -o link show type bridge | awk -F': ' '{print $2}'); do
		show_bridge "$br"
	done
}


unset wdebug
unset cprep
unset only
while test $# -gt 0 ; do
	case $1 in
	-p) pause=yes ;;
	-d) wdebug='--debug all --log-level debug2 --log-target syslog' ;;
	-s) shift ; only="$1" ;;
	-c) cprep=yes ;;
	-*) exit 2 ;;
	*)  break ;;
	esac
	shift
done

err=0
dir=${dir:-"/etc/sysconfig/network"}
cfg=${dir:+--ifconfig "compat:suse:$dir"}

test "X${dir}" != "X" -a -d "${dir}" || exit 2

bridge_name="${brdige_name:-br3}"
bridge_port="${bridge_port:-eth3}"

# permit to override above variables
config="${0//.sh/.conf}"
test -r "$config" && . "$config"

#set -x

step1()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifup all: $bridge_name { $bridge_port }"

	#
	# ifup $bridge_name with enslaved $bridge_port
	#

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$bridge_port"

	# port in the port list
	cat >"${dir}/ifcfg-$bridge_name" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$bridge_port'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifup $cfg all

	wicked ifstatus $cfg $bridge_name $bridge_port
	ip a s dev $bridge_name
	ip a s dev $bridge_port
	show_bridge $bridge_name

	echo ""
	if ip a s dev $bridge_port | grep -qs "master .*$bridge_name" ; then
		echo "WORKS: $bridge_port is enslaved into $bridge_name"
	else
		echo "ERROR: $bridge_port is not enslaved into $bridge_name"
		((err++))
	fi
	if wicked ifstatus $cfg $bridge_port | grep -qs compat:suse ; then
		echo "WORKS: $bridge_port has received generated config"
	else
		echo "ERROR: $bridge_port has not received generated config"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifreload all: $bridge_name { }"

	#
	# ifreload all, $bridge_name with enslaved $bridge_port removed
	#

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$bridge_port"

	# port in the port list
	cat >"${dir}/ifcfg-$bridge_name" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS=''
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg all

	wicked ifstatus $cfg $bridge_name $bridge_port
	ip a s dev $bridge_name
	ip a s dev $bridge_port
	show_bridge $bridge_name

	echo ""
	if ip a s dev $bridge_port | grep -qs "master .*$bridge_name" ; then
		echo "ERROR: $bridge_port is enslaved into $bridge_name"
		((err++))
	else
		echo "WORKS: $bridge_port is not enslaved into $bridge_name"
	fi
	if wicked ifstatus $cfg $bridge_port | grep -qs compat:suse ; then
		echo "ERROR: $bridge_port still has a config origin assigned"
		((err++))
	else
		echo "WORKS: $bridge_port has no config origin assigned"
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifreload all: $bridge_name { $bridge_port }"

	#
	# ifreload all: $bridge_name with enslaved $bridge_port
	#

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$bridge_port"

	# port in the port list
	cat >"${dir}/ifcfg-$bridge_name" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$bridge_port'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg all

	wicked ifstatus $cfg $bridge_name $bridge_port
	ip a s dev $bridge_name
	ip a s dev $bridge_port
	show_bridge $bridge_name

	echo ""
	if ip a s dev $bridge_port | grep -qs "master .*$bridge_name" ; then
		echo "WORKS: $bridge_port is enslaved into $bridge_name"
	else
		echo "ERROR: $bridge_port is not enslaved into $bridge_name"
		((err++))
	fi
	if wicked ifstatus $cfg $bridge_port | grep -qs compat:suse ; then
		echo "WORKS: $bridge_port has received generated config"
	else
		echo "ERROR: $bridge_port has not received generated config"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifreload $bridge_name: $bridge_name { }"

	#
	# ifreload $bridge_name, $bridge_name with enslaved $bridge_port removed
	#

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$bridge_port"

	# port in the port list
	cat >"${dir}/ifcfg-$bridge_name" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS=''
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg $bridge_name

	wicked ifstatus $cfg $bridge_name $bridge_port
	ip a s dev $bridge_name
	ip a s dev $bridge_port
	show_bridge $bridge_name

	echo ""
	if ip a s dev $bridge_port | grep -qs "master .*$bridge_name" ; then
		echo "ERROR: $bridge_port is enslaved into $bridge_name"
		((err++))
	else
		echo "WORKS: $bridge_port is not enslaved into $bridge_name"
	fi
	if wicked ifstatus $cfg $bridge_port | grep -qs compat:suse ; then
		echo "ERROR: $bridge_port still has a config origin assigned"
		((err++))
	else
		echo "WORKS: $bridge_port has no config origin assigned"
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifreload $bridge_name: $bridge_name { $bridge_port }"

	#
	# ifreload $bridge_name: $bridge_name with enslaved $bridge_port
	#

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$bridge_port"

	# port in the port list
	cat >"${dir}/ifcfg-$bridge_name" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$bridge_port'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg $bridge_name

	wicked ifstatus $cfg $bridge_name $bridge_port
	ip a s dev $bridge_name
	ip a s dev $bridge_port
	show_bridge $bridge_name

	echo ""
	if ip a s dev $bridge_port | grep -qs "master .*$bridge_name" ; then
		echo "WORKS: $bridge_port is enslaved into $bridge_name"
	else
		echo "ERROR: $bridge_port is not enslaved into $bridge_name"
		((err++))
	fi
	if wicked ifstatus $cfg $bridge_port | grep -qs compat:suse ; then
		echo "WORKS: $bridge_port has received generated config"
	else
		echo "ERROR: $bridge_port has not received generated config"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifreload $bridge_port: $bridge_name { }"

	#
	# ifreload $bridge_port, $bridge_name with enslaved $bridge_port removed
	#

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$bridge_port"

	# port in the port list
	cat >"${dir}/ifcfg-$bridge_name" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS=''
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg $bridge_port

	wicked ifstatus $cfg $bridge_name $bridge_port
	ip a s dev $bridge_name
	ip a s dev $bridge_port
	show_bridge $bridge_name

	echo ""
	if ip a s dev $bridge_port | grep -qs "master .*$bridge_name" ; then
		echo "ERROR: $bridge_port is enslaved into $bridge_name"
		((err++))
	else
		echo "WORKS: $bridge_port is not enslaved into $bridge_name"
	fi
	if wicked ifstatus $cfg $bridge_port | grep -qs compat:suse ; then
		echo "ERROR: $bridge_port still has a config origin assigned"
		((err++))
	else
		echo "WORKS: $bridge_port has no config origin assigned"
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: ifreload $bridge_port: $bridge_name { $bridge_port }"

	#
	# ifreload $bridge_port: $bridge_name with enslaved $bridge_port
	#

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$bridge_port"

	# port in the port list
	cat >"${dir}/ifcfg-$bridge_name" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$bridge_port'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg $bridge_port

	wicked ifstatus $cfg $bridge_name $bridge_port
	ip a s dev $bridge_name
	ip a s dev $bridge_port
	show_bridge $bridge_name

	echo ""
	if ip a s dev $bridge_port | grep -qs "master .*$bridge_name" ; then
		echo "WORKS: $bridge_port is enslaved into $bridge_name"
	else
		echo "ERROR: $bridge_port is not enslaved into $bridge_name"
		((err++))
	fi
	if wicked ifstatus $cfg $bridge_port | grep -qs compat:suse ; then
		echo "WORKS: $bridge_port has received generated config"
	else
		echo "ERROR: $bridge_port has not received generated config"
		((err++))
	fi

	echo ""
	echo "=== step $step: finished with $err errors"
}


cleanup()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return

	echo ""
	echo "=== $step: cleanup"

	wicked $wdebug ifdown $bridge_name $bridge_port
	rm -f "${dir}/ifcfg-$bridge_name"
	rm -f "${dir}/ifcfg-$bridge_port"
	if test -d "/sys/class/net/$bridge_port" ; then
		ip link delete $bridge_port && ((++err))
	fi
	if test -d "/sys/class/net/$bridge_name" ; then
		ip link delete $bridge_name || ((++err))
	fi
	echo "-----------------------------------"
	ps  ax | grep /usr/.*/wicked | grep -v grep
	echo "-----------------------------------"
	wicked ifstatus $cfg all
	echo "-----------------------------------"
	show_all_bridges
	echo "-----------------------------------"
	ls -l /var/run/wicked/nanny/
	echo "==================================="
}

step=0
errs=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0
step1   ; pause ; let step++ ; let errs+=$err ; err=0
step2   ; pause ; let step++ ; let errs+=$err ; err=0
step3   ; pause ; let step++ ; let errs+=$err ; err=0
step4   ; pause ; let step++ ; let errs+=$err ; err=0
step5   ; pause ; let step++ ; let errs+=$err ; err=0
step6   ; pause ; let step++ ; let errs+=$err ; err=0
step7   ; pause ; let step++ ; let errs+=$err ; err=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0

echo ""
echo "=== STATUS: finished $step step(s) with $errs errors"
exit $errs
