#!/bin/bash
#
#  iSCSI target for qa_sw_multipath:
#
#  randomly remove/re-add LUNs temporarily to enable an iSCSI/multipath client
#  to test robustness of multipathing


myname="$(basename "$0")"

function usage() {
	>&2 echo "
Usage:  $myname [-D] [-m mode] [-t target]
	$myname -h

	to keep manipulating the LUNs of iSCSI target \"target\" in the way indicated
	by \"mode\". Purpose is to assist in robustness tests.

	Script ends by backgrounding its action and reporting its PID.
	Terminate it by signaling. SIGINT SIGTERM trigger a proper
	tidy-up of the target before exiting.

Options:
	-h   Print this help and exit successfully

	-D   Activate debugging messages
	-f   Waiting time (in seconds) between each action. Default: 15
	-l   Just give a report about the iSCSI target's status, no further action
	-m   specify the mode how to handle the LUNs: one of

		\"addremove\" (default), \"onoffline\"

	-t   specify the local iSCSI target to handle: one of

	     iqn.2016-02.de.openqa		# (default) openQA supportserver standard target
	     iqn.2010-06.de.suse:multipath	# standard qa_test_multipath target on galileo.qam.suse.de
	     iqn.2012-09.de.suse:mpath2   	# secondary target on galileo.qam.suse.de, four paths
"
}
# Global variables:
# 	r/o:  $target
# 	r/w:  $iscsi_server $trecord $tid
#
function detect_target() {
	# FIXME: section for LIO iscsi target missing
	if systemctl is-active tgtd >/dev/null 2>&1; then
		iscsi_server="tgtd"
		trecord="$(tgtadm --lld iscsi --op show --mode target | \
			   sed -n -e "/^Target [1-9][0-9]*: $target/,/^Target [1-9]/ {
				/^Target/ {
					/$target/ ! q
				}
				p
			}")"
			tid="$(echo "$trecord" | sed -n -e "/^Target/ {
				s/^Target \([1-9][0-9]*\):.*\$/\1/p
				q
			}")"
	elif [ -f /proc/net/iet/volume ] ; then
		iscsi_server="ietd"
		trecord="$(sed -n -e "/^tid:[0-9]* name:$target/ {
				p
				:luns
				n
				/^[[:blank:]]*lun:/ {
					p
					b luns
				}
				q
			}" /proc/net/iet/volume)"

		tid="$(echo "$trecord" | sed -n -e "/^tid:.* name:$target/s,tid:\([0-9]*\) name:.*,\1,p")"
	fi	# if [ -f /proc/net/iet/volume ]

	if  [ "$tid" -gt 0 ] 2>/dev/null; then
		[ -n "$DEBUG" ] && echo "DEBUG: detected TID: \"$tid\" for target: $target."
	else
		echo "ERROR: detect_target(): detected BAD TID: \"$tid\" for target: $target." >&2
		return 1
	fi

	[ -n "$DEBUG" ] && echo "
DEBUG: Target: $target: full record:

$trecord

\$tid: $tid
"
	return 0
}

# Global variables:
#	r/o: $iscsi_server $trecord $tid
#	r/w: $firstlun $lastlun $path[] $online[]
#
function detect_luns() {
	local lun;

	lastlun=0
	# FIXME: section for LIO iscsi target missing
	if [ "$iscsi_server" == "tgtd" ] ; then
		firstlun=1
		# Warning: DONT pipe here lest the result is just in a subshell!!
		while read w1 w2 w3 w4 rest; do
			case "$w1" in
			    LUN:)	lun="$w2"
					[ "$lun" -eq 0 ] && continue	# LUN 0: reserved, not a disk
					# [ -n "$DEBUG" ] && echo -e "DEBUG: Evaluating trecord line: $w1 $w2 $w3 $w4 $rest"
					online[lun]="online"
					[ "$lun" -gt "$lastlun" ] && lastlun="$lun"
					# [ -n "$DEBUG" ] && echo -e "DEBUG: LUN $lun: \$lastlun is $lastlun"
					;;
			    Backing)	[ "$lun" -eq 0 ] && continue	# LUN 0: reserved, not a disk
					[ "$w1 $w2 $w3" != "Backing store path:" ] && continue;
					# [ -n "$DEBUG" ] && echo -e "DEBUG: Evaluating trecord line: $w1 $w2 $w3 $w4 $rest"
					path[lun]="$w4"
					[ -n "$DEBUG" ] && echo -e "\tLUN: $lun\tpath: ${path[lun]}"
					;;
			esac
		done < <(echo "$trecord")
		no_luns="$lastlun"
	elif [ "$iscsi_server" == "ietd" ] ; then
		firstlun=0
		# WARNING: the LUN IDs do not need to be monotonously increasing!
		#          Need to find the max!
		#          FIXME: there might even be gaps?! For now, let's assume "no gaps"
		for lun in $(echo "$trecord" | sed -n -e's/^[[:blank:]]*lun:\([0-9]*\) .*$/\1/p') ; do
			[ "$lun" -gt "$lastlun" ] && lastlun="$lun"
		done

		let "no_luns = lastlun + 1"
		for lun in $(seq "$firstlun" "$lastlun") ; do
			# For robustness, we keep track of *all* paths.
			# They are identical for now, but this does not need to remain so.
			path[lun]="$(echo "$trecord" | sed -n -e"/^[[:blank:]]*lun:$lun[[:blank:]]/s,^.*[[:blank:]]path:\(/.*\)\$,\1,p")"
			[ -n "$DEBUG" ] && echo -e "\tLUN: $lun\tpath: ${path[lun]}"
			online[lun]="online"
		done
	else
		# unsupported $iscsi_server
		return 1
	fi	# if [ "$iscsi_server" == .....

	if [ "$no_luns" -eq 0 ] ; then
		echo "ERROR: detect_luns(): NO luns detected for tid: $tid" >&2
		return 1
	fi	# if [ "$no_luns" -eq 0 ]

	[ -n "$DEBUG" ] && echo "DEBUG: Detected $no_luns LUNs: $firstlun,...,$lastlun:"
	luns_online="$no_luns"
	[ -n "$DEBUG" ] && echo ""
	return 0
}

function report_lun_state() {
	local lun;
	echo -e "iSCSI target: $target (TID: $tid)\n"
	for lun in $(seq -w "$firstlun" "$lastlun"); do
		echo "LUN $lun: ${online[lun]}"
	done
}

function add_lun {
	local lun="$1"
	# FIXME: section for LIO iscsi target missing
	if [ "$iscsi_server" == "tgtd" ] ; then
		# openQA supportserver, SLES-12 SP3
		tgtadm --lld iscsi --mode logicalunit --op new \
			--tid=$tid --lun=$lun \
		--device-type disk --backing-store "${path[lun]}" \
		&& tgtadm --lld iscsi --mode logicalunit --op update \
			--tid=$tid --lun=$lun --params scsi_id="$ScsiId" \
		|| return 1	# failure considered nonfatal, no action
	elif [ "$iscsi_server" == "ietd" ] ; then
		# galileo.qam.suse.de, SLES-11 SP3
		ietadm --op new --tid=$tid --lun=$lun \
			--params Type=blockio,ScsiId="$ScsiId",Path="${path[lun]:-$path_fallback}" \
		|| return 1	# failure considered nonfatal, no action
	else
		return 1	# no action
	fi
	let "luns_online += 1"
	online[lun]="online"
}

function remove_lun {
	local lun="$1"
	# FIXME: section for LIO iscsi target missing
	if [ "$iscsi_server" == "tgtd" ] ; then
		# openQA supportserver, SLES-12 SP3
		tgtadm --lld iscsi --mode logicalunit --op delete \
			--tid=$tid --lun=$lun \
		|| return 1	# failure considered nonfatal, no action
	elif [ "$iscsi_server" == "ietd" ] ; then
		# galileo.qam.suse.de, SLES-11 SP3
		ietadm --op delete --tid=$tid --lun=$lun \
		|| return 1	# failure considered nonfatal, no action
	else
		return 1	# no action
	fi
	let "luns_online -= 1"
	online[lun]="offline"
}

function online_lun {
	local lun="$1"
	# FIXME: section for LIO iscsi target missing
	# only supported for the tgtd iSCSI server
	if [ "$iscsi_server" == "tgtd" ] ; then
		# openQA supportserver, SLES-12 SP3
		tgtadm --lld iscsi --mode logicalunit --op update \
			--tid=$tid --lun=$lun \
			--params online=1 \
		|| return 1	# failure considered nonfatal, no action
	else
		return 1	# no action
	fi
	let "luns_online += 1"
	online[lun]="online"
}

function offline_lun {
	local lun="$1"
	# only supported for the tgtd iSCSI server

	# FIXME: section for LIO iscsi target missing
	if [ "$iscsi_server" == "tgtd" ] ; then
		# openQA supportserver, SLES-12 SP3
		tgtadm --lld iscsi --mode logicalunit --op update \
			--tid=$tid --lun=$lun \
			--params online=0 \
		|| return 1	# failure considered nonfatal, no action
	else
		return 1	# no action
	fi
	let "luns_online -= 1"
	online[lun]="offline"
}

# Global variables:
#       r/o: $treat_lun $firstlun $lastlun $path[]
#       r/w: $online[]
#
function toggle_lun {
	local toggle_me
	local fail

	# we might need a few iterations for getting a suitable $RANDOM
	local done=""
	until [ -n "$done" ] ; do
		toggle_me="$RANDOM"
		# turn $RANDOM into a random index between $firstlun and $lastlun
		let "toggle_me += -(toggle_me/no_luns)*no_luns + firstlun"
		if [ "${online[toggle_me]}" == "online" ] ; then
			# NO action if there is only one online LUN left. Rather repeat with a new $RANDOM.
			# FIXME: if the paths vary, we want at least one LUN remain for each path.
			if [ "$luns_online" -lt 2 ]; then
				# wait a bit, then try with a new $RANDOM value
				sleep 1
				continue
			fi
			case "$treat_lun" in
			    addremove)
				remove_lun "$toggle_me" && fail="" || fail=" (nonfatal) NOT"
				[ -n "$DEBUG" ] && echo "DEBUG:$fail deleted LUN $toggle_me"
				[ -z "$fail" ] || echo "WARNING: remove_lun $toggle_me failed (probably nonfatal)" >&2
				;;
			    onoffline)
				if offline_lun "$toggle_me"; then
					[ -n "$DEBUG" ] && echo "DEBUG: taken offline: LUN $toggle_me"
				else
					echo "WARNING: offline_lun() failed (is iSCSI server $iscsi_server supported?)" >&2
					continue
				fi	# if offline_lun "$toggle_me"
				;;
			    *)		echo "Int ERROR: toggle_lun(): unknown \$action: $treat_lun. Doing nothing." >&2
					continue
				;;
			esac
			done="yes"
		elif [ "${online[toggle_me]}" == "offline" ] ; then
			case "$treat_lun" in
			    addremove)
				add_lun "$toggle_me" && fail="" || fail=" (nonfatal) NOT"
				[ -n "$DEBUG" ] && echo "DEBUG:$fail Re-Added LUN $toggle_me"
				[ -z "$fail" ] || echo "WARNING: add_lun $toggle_me failed (probably nonfatal)" >&2
				;;
			    onoffline)
				if online_lun "$toggle_me"; then
					[ -n "$DEBUG" ] && echo "DEBUG: brought online: LUN $toggle_me"
				else
					echo "WARNING: online_lun() failed (is iSCSI server $iscsi_server supported?)" >&2
					continue
				fi	# if online_lun "$toggle_me"
				;;
			    *)		echo "Int ERROR: toggle_lun(): unknown \$action: $treat_lun. Doing nothing." >&2
					continue
				;;
			esac
			done="yes"
		else
			echo "Int ERROR: toggle_lun(): Unexpected value: \${online[$toggle_me]} == ${online[toggle_me]}." >&2
		fi
	done
	if [ -n "$DEBUG" ]; then
		echo "
DEBUG: result of invoking toggle_lun()
--------------------------------------"
		report_lun_state
		echo
	fi	# if [ -n "$DEBUG" ]
	return 0
}

function tidyup_target {
	local lun

	# Add a temporary sentinel to have at least one LUN remaining throughout
	let "tmplun = no_luns + 1"
	path[tmplun]="${path[lastlun]}"
	[ -n "$DEBUG" ] && echo "tidyup_target(): add_lun $tmplun"
	add_lun $tmplun
	sleep 1

	for lun in $(seq $firstlun $lastlun); do
		# FIXME: better check whether $lun is present in the first place
		#        Fails here are likely nonfatal, just annoying
		[ -n "$DEBUG" ] && echo "tidyup_target(): remove_lun $lun"
		remove_lun "$lun" || echo "LUN $lun probably already absent; failure hopefully harmless" >&2
	done
	for lun in $(seq $firstlun $lastlun); do
		[ -n "$DEBUG" ] && echo "tidyup_target(): add_lun $lun"
		add_lun "$lun"
	done
	[ -n "$DEBUG" ] && echo "tidyup_target(): remove_lun $tmplun"
	remove_lun $tmplun
	[ -n "$DEBUG" ] && { echo -e "\nAfter final tidy-up:"; detect_target ; }
	return 0
}

function tidyup_all {
	tidyup_target
	rm -f "$pidfile"
	exit 0
}

# ACTION

# Cmdline evaluation and sanity checks
#

# Defaults
DEBUG=""
wait_between=15
just_report=""
# FIXME: (clumsily) hardcoded to enable other processes to find the location
#        (see openQA module tests/supportserver/flaky_mp_iscsi.pm)
pidfile="/tmp/multipath_flaky_luns.pid"
treat_lun="addremove"
target="iqn.2016-02.de.openqa"

while getopts hDf:lm:t: optchar ; do
    case "$optchar" in
	h)      usage ; exit 0            ;;
	D)      DEBUG="yes"               ;;
	f)      wait_between="$OPTARG"    ;;
	l)      just_report="yes"         ;;
	m)      treat_lun="$OPTARG"       ;;
	t)      target="$OPTARG"          ;;
	*)      usage ; exit 1            ;;
    esac
done

if ! [ "$wait_between" -gt 0 ] >/dev/null 2>&1; then
	echo "$myname: ERROR: option -f: invalid value $wait_between. Aborting...">&2
	usage
	exit 1
fi

if ! rm -rf "$pidfile" ; then
	"$myname: ERROR: Unable to clean out needed PID file: $pidfile. Aborting...">&2
	exit 1
fi

case "$target" in
	iqn.2010-06.de.suse:multipath)	# standard qa_test_multipath target on galileo.qam.suse.de
	    ScsiId=mpath1; path_fallback=/dev/qa/multipath
	    ;;
	iqn.2012-09.de.suse:mpath2)	# secondary target on galileo.qam.suse.de, four paths
	    ScsiId=mpath2; path_fallback=/dev/qa/mpath2
	    ;;
	iqn.2016-02.de.openqa)		# openQA supportserver standard target
	    ScsiId=mpatha; path_fallback=/dev/qa/mpatha
	    ;;
	* ) echo "$myname: ERROR: cmdline arg $target: unknown iSCSI target. Aborting...">&2
	    exit 1
	    ;;
esac

case "$treat_lun" in
	addremove|onoffline)
		: ;;
	*)	echo "$myname: ERROR: cmdline arg $treat_lun: must be \"addremove\" or \"onoffline\". Aborting...">&2
		exit 1
		;;
esac

detect_target || {
	echo "$myname: ERROR: detect_target() failed. Aborting...">&2
	exit 1
}
detect_luns || {
	echo "$myname: ERROR: detect_luns() failed for target: $target. Aborting...">&2
	exit 1
}
#
# Done: cmdline evaluation and sanity checks

if [ "$just_report" == "yes" ] ; then
	report_lun_state
	exit 0
fi

# Main action in the background, expected to get
# terminated by signaling
#
# Note: outputting $! to stdout and trying to capture it via
# (subshelled) command substitution will hang. Therefore,
# a hardcoded PIDfile is utilized.
#
{
trap 'tidyup_all' SIGHUP SIGINT SIGTERM
while true ; do
	toggle_lun
	sleep "$wait_between"
done
} & echo $! >"$pidfile"
