#!/bin/bash

pause()
{
	test "X$pause" = X && return
	echo -n "Press enter to continue...."
	read
}
policy_name2path()
{
        local path="$1"
        path="${path//[_]/__}"
        path="${path//[-]/_m}"
        path="${path//[.]/_d}"
        echo "$path"
}
policy_file()
{
	local name="policy_$1"
	local path=$(policy_name2path "${name}")
	echo "$run/$path.xml"
}
policy_exists()
{
	local file=$(policy_file "$1")
	test -e "$file"
}
policy_delete()
{
	local name file rc=0
	for name in "$@" ; do
		file=$(policy_file "$name")
		test -e "$file" || continue
		echo "# rm -f -- \"$file\""
		rm -f "$file"
		((rc++))
	done
	return $rc
}

device_exists()
{
	test -d "/sys/class/net/$1"
}
device_is_up()
{
	LC_ALL=POSIX ip link show dev "$1" 2>/dev/null | grep -qs "[<,]UP[,>]"
}
device_create()
{
	local name="$1" ; shift
	local type="$1" ; shift

	device_exists "$name" && return 0

	case $type in
	tap)
		echo "# ip tuntap add $name mode $type $*"
		ip tuntap add "$name" mode "$type" "$@"
		;;
	dummy|veth)
		echo "# ip link add $name type $type $*"
		ip link add "$name" type "$type" "$@"
		;;
	*)	return 2 ;;
	esac
}
device_delete()
{
	local name rc=0
	for name in "$@" ; do
		device_exists "$name" || continue
		echo "# ip link delete dev $name"
		ip link delete "$name"
		((rc++))
	done
	return $rc
}
device_ifcfg_delete()
{
	local name file

	# --cfg-dir parameter is a must
	test "X$dir" != "X" -a -d "$dir" || return 1
	for name in "$@" ; do
		case "$name" in
		lo) continue ;;
		esac
		# firewalld may create .bak file
		for file in "${dir}/ifcfg-${name}" \
			"${dir}/ifcfg-${name}.bak" ;
		do
			test -f "$file" || continue
			echo "# rm -v -f -- \"${file}\""
			rm -v -f -- "${file}"
		done
	done
}

print_test_description()
{
	test_description;
}

log_device_config()
{
	out="${test_output_dir}/config-${step}/"
	mkdir -p "$out"
	ifc=()
	if [ "$1" == "all" ]; then
		for dev in "$dir"/ifcfg-*; do
			ifc+=("${dev:6}")
		done
	else
		for dev in "$@" ; do
			local file="${dir}/ifcfg-${dev}"
			[ "XXX$dev" == "XXX" ] && continue
			[ ! -e "$file" ] && continue
			ifc+=("${dev}")
		done
	fi

	readarray -t ifc_uniq <<< "$(for a in "${ifc[@]}"; do echo "$a"; done | sort | uniq)"

   	{
		for dev in "${ifc_uniq[@]}"; do
			local file="${dir}/ifcfg-${dev}"
			echo "== $file =="
			cat "$file"
			echo ""
		done
	} > "${out}config.cfg"

	wicked show-config $cfg > "${out}show_config_all.xml"

	if [ "$verbose" == "yes" ]; then
		cat "${out}config.cfg"
		echo "==== ${out}show_config_all.xml ===="
		cat "${out}show_config_all.xml"
	fi

	if [[ "$step" =~ ^step[0-9]+$ ]]; then
		num="${step:4}"
		num=$((num - 1))
		test -d "log/config-step${num}/" &&
			diff -urN "log/config-step${num}/" "${out}" > "log/config-${step}.diff"
	fi
}

print_device_status()
{
	out="$test_output_dir/"
	mkdir -p "$out"
   	{
		echo "# wicked ifstatus $cfg ""$*"
		wicked ifstatus $cfg "$@"
		echo ""

		for dev in "$@"; do
			if [ "$dev" == "all" ]; then
				echo "# ip a s"
				ip a s
			else
				echo "# ip a s dev $dev"
				ip a s dev $dev
			fi
		done
		echo ""
	} > "${out}status-${step}.txt"

	if [ "$verbose" == "yes" ]; then
		cat "${out}status-${step}.txt"
	fi
}

print_bridges()
{
	echo "Bridge          Ports"
        for br in $(ip -o link show type bridge | awk -F': ' '{print $2}'); do
		printf "%-15s %s\n" "$br" "$(bridge link | grep "master $br" | awk -F': ' '{print $2}' | xargs echo -n)"
        done
	echo ""
}

check_device_exists()
{
    if device_exists "$1" ; then
		echo "WORKS: $1 exists"
	else
		red "ERROR: $1 is missing"
		((err++))
	fi
}

check_device_not_exists()
{
    if ! device_exists "$1" ; then
		echo "WORKS: device $1 does not exist"
	else
		red "ERROR: device $1 exists"
		((err++))
	fi
}

check_device_is_up()
{
    if device_is_up "$1" ; then
		echo "WORKS: $1 is up"
	else
		red "ERROR: $1 is NOT up"
		((err++))
	fi
}
check_device_is_down()
{
    if ! device_is_up "$1" ; then
		echo "WORKS: $1 is down"
	else
		red "ERROR: $1 is NOT down"
		((err++))
	fi
}

check_device_has_port()
{
	local master=$1; shift
	local count=0
	local start_time

	start_time="$(date "+%s")"

	for dev in "$@"; do
		if ip a s dev $dev 2>/dev/null | grep -qs "master .*$master" ; then
			count=$((count + 1))
		fi
	done

	if [ $count -eq 0 ]; then
		red "ERROR: Missing any of $* as port of $master"
		((err++))
		return
	fi

	missing=""
	while [ $(( $(date "+%s") - start_time )) -lt "$wait_for_ports" ]; do
		missing=""
		for dev in "$@"; do
			if ! ip a s dev $dev 2>/dev/null | grep -qs "master .*$master" ; then
				[ -z "$missing" ] || missing="$missing "
				missing="$missing$dev"
			fi
		done

		if [ -z "$missing" ]; then
			echo "WORKS: $* are ports of $master"
			return;
		fi
		sleep 1;
	done

	red "ERROR: Missing $missing as port of $master"
	((err++))
}

check_device_has_not_port()
{
	local master=$1; shift

	for dev in "$@"; do
		if ip a s dev $dev 2>/dev/null | grep -qs "master .*$master" ; then
			red "ERROR: $dev is port of $master"
			((err++))
		else
			echo "WORKS: $dev is not port of $master"
		fi
	done
}

check_device_has_link()
{
	local dev=$1; shift
	local link=$1; shift

	if ip a s dev "$dev" | grep -qs "$dev@$link" >& /dev/null; then
		echo "WORKS: $dev is linked to $link"
	else
		red "ERROR: Missing link $link on for $dev"
		((err++))
	fi
}
check_device_has_compat_suse_config()
{
	if wicked ifstatus $cfg $1 | grep -qs compat:suse ; then
		echo "WORKS: $1 has received generated config"
	else
		red "ERROR: $1 has not received generated config"
		((err++))
	fi
}
check_device_has_not_compat_suse_config()
{
	if ! wicked ifstatus $cfg "$1" | grep -qs compat:suse ; then
		echo "WORKS: $1 has not received generated config"
	else
		red "ERROR: $1 has received generated config"
		((err++))
	fi
}
check_ovsbr_has_port()
{
	local master=$1; shift
	local ovs_system=${ovs_system:-ovs-system}

	for dev in "$@"; do
		check_device_has_port "$ovs_system" "$dev"
		if ovs-vsctl list-ports $master | grep -qsw $dev; then
			echo "WORKS: $dev is port of $master";
		else
			red "ERROR: $dev is not port of $master";
		fi
	done
}
check_ovsbr_has_not_port()
{
	local master=$1; shift
	local ovs_system=${ovs_system:-ovs-system}

	for dev in "$@"; do
		check_device_has_not_port "$ovs_system" "$dev"
		if ! ovs-vsctl list-ports $master | grep -qsw "$dev"; then
			echo "WORKS: $dev is port not of $master";
		else
			red "ERROR: $dev is port of $master";
		fi
	done
}

check_policy_exists()
{
    if policy_exists $1 ; then
		echo "WORKS: policy $1 exists"
	else
		red "ERROR: policy $1 is missing"
		((err++))
	fi
}
check_policy_not_exists()
{
    if ! policy_exists $1 ; then
		echo "WORKS: policy $1 is missing"
	else
		red "ERROR: policy $1 exists"
		((err++))
	fi
}

check_vlan_id()
{
	if ip -d link show dev $1 | grep 'vlan protocol' | grep " id $2 " >/dev/null ; then
		echo "WORKS: device $1 has VLAN_ID=$2 set"
	else
		red "ERROR: device $1 is not in VLAN $2"
		((err++))
	fi
}



color() {
    local NC
    local c=$1
    if [ "$use_colors" == "yes" ]; then
        NC="$(tput sgr0)"
        case "$c" in
            red|RED) c="$(tput setaf 1)";;
            green|GREEN) c="$(tput setaf 2)";;
            bold|BOLD) c="$(tput bold)";;
            *);;
        esac
    else
        NC=""; c="";
    fi
    echo "$c$2$NC"
}
bold(){
    color BOLD "$1"
}
red(){
    color RED "$1"
}
green(){
    color GREEN "$1"
}
print_result()
{
	local err_cnt=$1
	local msg=$2
	font_color=$([ "$err_cnt" -gt 0 ] && echo "red" || echo "")
	color "$font_color" "$msg"
}

print_help()
{
	echo " -p | --pause         Pause between each teststep"
	echo " -d | --debug         Use debug output on wicked calls"
	echo " -l | --list          List all steps"
	echo " -s | --step <func>   Run only the given step"
	echo " --cfg-dir <dir>      Path to ifcfg files (Default: /etc/sysconfig/network)"
	echo " --stop-on-err        Stop execution on first errounous step"
	echo " --with-port-config   If there is a test which have a optional need for the"
	echo "                      port config (e.g. a bridge port), then this port config"
	echo "                      will be explicit created."
	echo " --wait-for-ports     Used to specify the wait time, till all ports are"
	echo "                      assigned to its parent. Usually it should be set to"
	echo "                      WAIT_FOR_INTERFACES default is $wait_for_ports"
	echo " --color              Force enable colored output."
	echo " --verbose            Enable verbose output."
	echo " --description        Prints the test description."
	echo " -h | --help          Print this help."
}

wdebug='--log-level info --log-target syslog'
wait_for_ports=$(source /etc/sysconfig/network/config 2>/dev/null; echo "${WAIT_FOR_INTERFACES:-30}")
unset cprep
unset only
unset list
unset use_colors
unset stop_on_error
unset with_port_config
unset dir
verbose="no"
test_output_dir="log"
[ "$(tput colors)" -ge 8 ] && use_colors=yes
while test $# -gt 0 ; do
	case "$1" in
	-p|--pause) pause=yes ;;
	-d|--debug) wdebug='--debug all --log-level debug2 --log-target syslog' ;;
	-s|--step) shift ; only="$1" ;;
	--cfg-dir) shift; dir="$1" ;;
	-l|--list) list=yes;;
	--stop-on-err*) stop_on_error=yes;;
	--wait-for-ports) shift; wait_for_ports="$1" ;;
	--color) use_colors=yes;;
	--verbose) verbose=yes;;
	--with-port-config) with_port_config=yes;;
	--info|--description|--desc) test_description; exit 0;;
	-h|--help) print_help; exit 0 ;;
	-*) print_help; exit 2 ;;
	*)  break ;;
	esac
	shift
done

dir=${dir:-"/etc/sysconfig/network"}
cfg=${cfg:---ifconfig "compat:suse:$dir"}
run=${run:-/run/wicked/nanny}

test "X${dir}" != "X" -a -d "${dir}" || exit 2

err=0
step=0
errs=0
steps="$(typeset -f | grep -P -o "^step[0-9]+\s+" | sort -n -k 1.5)"

if [ "$list" = "yes" ]; then
	for func in $steps; do
		echo  " $func"
	done
else
	for func in $steps; do
		test "X$only" = "X" -o "X$only" = "X$func" || continue
		step="${func}";
		echo ""
		bold "=== $step: start"
		time $func "$step";
		echo ""
		print_result "$err" "=== $step: finished with $err errors"
		pause ;
		((errs+=$err)) ; err=0
		[ "$stop_on_error" == "yes" ] && [ "$errs" -gt 0 ] && break;
	done

	echo ""
	print_result "$errs" "=== STATUS: failed with $errs errors"
fi

exit $errs
