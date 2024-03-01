#!/bin/bash

pause()
{
	test "X$pause" = X && return
	echo -n "Press enter to continue...."
	read
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
dir=${1:-"/etc/sysconfig/network"}
cfg=${dir:+--ifconfig "compat:suse:$dir"}

bridge=brdummy
dummy0=dummy0
dummy1=dummy1
tap0=tap0

# permit to override above variables
config="${0//.sh/.conf}"
test -r "$config" && . "$config"

test "X${dir}" != "X" -a -d "${dir}" || exit 2

#set -x

step1()
{
	echo ""
	echo "=== $step: ifup $bridge { $dummy0 + $tap0 }"

	cat >"${dir}/ifcfg-$dummy0" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$dummy1" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$bridge" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$dummy0'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	modprobe -qs dummy
	modprobe -qs tap

	wicked $wdebug ifup $cfg all
	ip tuntap add $tap0 mode tap
	ip link set master $bridge up dev $tap0

	wicked ifstatus $cfg all
	ip a s dev $dummy0
	ip a s dev $dummy1
	ip a s dev $tap0

	if ip a s dev $dummy0 | grep -qs "master .*$bridge" ; then
		if ip a s dev $dummy1 | grep -qs "master .*$bridge" ; then
			echo "ERROR: $dummy1 is enslaved into $bridge"
			((err))
		fi
	else
		echo "ERROR: $dummy0 is not enslaved into $bridge"
		((err))
	fi
	if ! ip a s dev $tap0 | grep -qs "master .*$bridge" ; then
		echo "ERROR: $tap0 is not enslaved into $bridge"
		((err))
	fi
	if wicked ifstatus $cfg $tap0 | grep -qs compat:suse ; then
		echo "ERROR: $tap0 has received generated config"
		((err))
	fi
}

step2()
{
	echo ""
	echo "=== $step: ifup $bridge { $dummy0 + $tap0 } again"

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifup $cfg all

	wicked ifstatus $cfg all
	ip a s dev $dummy0
	ip a s dev $dummy1
	ip a s dev $tap0

	if ip a s dev $dummy0 | grep -qs "master .*$bridge" ; then
		if ip a s dev $dummy1 | grep -qs "master .*$bridge" ; then
			echo "ERROR: $dummy1 is enslaved into $bridge"
			((err))
		fi
	else
		echo "ERROR: $dummy0 is not enslaved into $bridge"
		((err))
	fi
	if ! ip a s dev $tap0 | grep -qs "master .*$bridge" ; then
		echo "ERROR: $tap0 is not enslaved into $bridge"
		((err))
	fi
	if wicked ifstatus $cfg $tap0 | grep -qs compat:suse ; then
		echo "ERROR: $tap0 has received generated config"
		((err))
	fi
}

step3()
{
	echo ""
	echo "=== $step: ifreload $bridge { $dummy1 + $tap0 }"

	# change bridge to use $dummy1 instead + ifreload
	cat >"${dir}/ifcfg-$bridge" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$dummy1'
	EOF

	wicked show-config > "config-step-${step}.xml"
	test "X$cprep" = X || return

	wicked $wdebug ifreload $cfg all

	wicked ifstatus $cfg all
	ip a s dev $dummy0

	if ip a s dev $dummy1 | grep -qs "master .*$bridge" ; then
		if ip a s dev $dummy0 | grep -qs "master .*$bridge" ; then
			echo "ERROR: $dummy0 still enslaved into $bridge"
			((err))
		fi
	else
		echo "ERROR: $dummy1 not enslaved into $bridge"
		((err))
	fi
	if ! ip a s dev $tap0 | grep -qs "master .*$bridge" ; then
		echo "ERROR: $tap0 is not enslaved into $bridge"
		((err))
	fi
	if wicked ifstatus $cfg $tap0 | grep -qs compat:suse ; then
		echo "ERROR: $tap0 has received generated config"
		((err))
	fi
}

cleanup()
{
	echo ""
	echo "=== $step: cleanup"

	wicked $wdebug ifdown $bridge $dummy0 $dummy1 $tap0
	rm -f "${dir}/ifcfg-$dummy0"
	rm -f "${dir}/ifcfg-$dummy1"
	rm -f "${dir}/ifcfg-$bridge"
	ip link delete $bridge
	ip link delete $dummy0
	ip link delete $dummy1
	ip link delete $tap0
	rmmod dummy &>/dev/null
	rmmod tap   &>/dev/null
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
