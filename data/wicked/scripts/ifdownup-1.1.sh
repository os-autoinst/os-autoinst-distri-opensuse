#!/bin/bash

pause()
{
	test "X$pause" = X && return
	echo -n "Press enter to continue...."
	read
}

wdebug='--log-level info --log-target syslog'
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
dir=${1:-"/etc/sysconfig/network"}
cfg=${dir:+--ifconfig "compat:suse:$dir"}
run="/run/wicked/nanny"

test "X${dir}" != "X" -a -d "${dir}" || exit 2

# some default config:
# dummy is a corner case -> behaves differently to
# a NIC/SR-IOV as wicked is able to create them …
base=dummy1
vlanid="11"
vlan="vlan${vlanid}"

baseip="192.168.10.10/24"
vlanip="192.168.11.10/24"

# permit to override above variables
config="${0//.sh/.conf}"
test -r "$config" && . "$config"

#set -x

step1()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return
	echo ""
	echo "=== step $step: ifup ${base} + ${vlan}@${base}"

	cat >"${dir}/ifcfg-${base}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${baseip:+IPADDR='${baseip}'}
	EOF

	cat >"${dir}/ifcfg-${vlan}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${vlanip:+IPADDR='${vlanip}'}
		ETHERDEVICE='${base}'
		VLAN_ID='${vlanid}'
	EOF

	{
		echo "== "${dir}/ifcfg-${base}" =="
		cat "${dir}/ifcfg-${base}"
		echo "== "${dir}/ifcfg-${vlan}" =="
		cat "${dir}/ifcfg-${vlan}"
	} | tee "config-step-${step}.cfg"
	wicked show-config > "config-step-${step}.xml"
	#wicked show-policy > "policy-step-${step}.xml"

	test "X$cprep" = X || return

	echo "# wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	echo "# wicked $ifstatus $cfg $base $vlan"
	wicked ifstatus $cfg $base $vlan
	echo ""

	for dev in $base $vlan ; do
		echo "# ip a s dev $dev"
		ip a s dev $dev || ((err++))
	done

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return
	echo ""
	echo "=== step $step: ifdown ${base}"

	echo "# wicked ifstatus $cfg $base $vlan"
	wicked ifstatus $cfg $base $vlan
	echo ""

	echo "# wicked $wdebug ifdown $base"
	wicked $wdebug ifdown $base
	echo ""

	echo "# wicked ifstatus $cfg $base $vlan"
	wicked ifstatus $cfg $base $vlan
	echo ""

	for dev in $base $vlan ; do
		echo "# ip a s dev $dev"
		ip a s dev $dev && ((err++))
	done

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return
	echo ""
	echo "=== step $step: ifup ${base}"

	echo "# wicked ifstatus $cfg $base $vlan"
	wicked ifstatus $cfg $base $vlan
	echo ""

	echo "# wicked $wdebug ifup $cfg $base"
	wicked $wdebug ifup $cfg $base
	echo ""

	echo "# wicked ifstatus $cfg $base $vlan"
	wicked ifstatus $cfg $base $vlan
	echo ""

	for dev in $base $vlan ; do
		echo "# ip a s dev $dev"
		ip a s dev $dev || ((err++))
	done

	echo ""
	echo "=== step $step: finished with $err errors"
}


cleanup()
{
	test "X$only" = "X" -o "X$only" = "X$step" || return
	echo ""
	echo "=== cleanup step $step: ifdown ${base}"

	echo "# wicked ifdown $base $vlan"
	wicked ifdown $base $vlan

	# we bring wickedd-nanny into a non-working state,
	# so delete everything and restart the daemons ...

	rm -vf -- "${dir}/ifcfg-${base}"
	rm -vf -- "${dir}/ifcfg-${vlan}"
	rm -vf -- "$run/policy__${base}"*
	rm -vf -- "$run/policy__${vlan}"*
	for dev in $vlan $base ; do
		if test -d "/sys/class/net/$dev" ; then
			echo "# ip link delete dev $dev"
			ip link delete dev $dev
		fi
	done

	echo "# rcwickedd restart"
	rcwickedd restart
	sleep 3

	echo ""
	echo "=== cleanup step $step: finished with $err errors"
}

step=0
errs=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0
step1   ; pause ; let step++ ; let errs+=$err ; err=0
step2   ; pause ; let step++ ; let errs+=$err ; err=0
step3   ; pause ; let step++ ; let errs+=$err ; err=0
cleanup ; pause ; let step++ ; let errs+=$err ; err=0

echo ""
echo "=== STATUS: finished $step step(s) with $errs errors"
exit $errs
