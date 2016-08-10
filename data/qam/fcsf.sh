#!/bin/bash
#
#       Concerns ctcs2-generated "rpmlist" and "hwinfo" files
#       Fakes consistency throughout the first-level subdirs of $PWD
#	Cf. bnc#560428
#
#  $Id: fake_consistent_snapshotfiles.sh,v 1.9 2015/10/07 12:48:07 rd-qa Exp $
#  $Log: fake_consistent_snapshotfiles.sh,v $
#  Revision 1.9  2015/10/07 12:48:07  rd-qa
#  IMPROVED:       option -R (revert): better message in case there is
#                  nothing to revert
#
#  Revision 1.8  2013/05/23 16:11:16  rd-qa
#  ADDED:          support for faking the kernel report file, too
#                  (which is reckless indeed...)
#
#  Revision 1.7  2013/02/28 11:19:49  rd-qa
#  ADDED:          support for shell patterns as optarg for the -y option
#                  so that multiple-year submissions can be dealt with
#
#  Revision 1.6  2011/01/27 15:16:06  rd-qa
#  BUGFIX:         the year spec (option -y) was ineffective for $refdir
#
#  Revision 1.5  2011/01/26 13:30:59  kgw
#  ADDED:          extra return value for a dry run detecting the
#                  need to fake
#
#  Revision 1.4  2010/08/30 09:19:25  kgw
#  ADDED:          reference to bnc#560428 in the "usage" message.
#
#  Revision 1.3  2010/05/03 10:36:50  kgw
#  FIXED:          a bash syntax error
#  ADDED:          missing d option in help text command line
#
#  Revision 1.2  2010/05/03 09:25:21  kgw
#  ADDED:          new option -P to specify the work parent directory
#
#  Revision 1.1	 2010/05/03 09:17:33  kgw
#  Initial Checkin.
#  Script as of Feb 26, 2010: functional, hardcoded workdir: $PWD
#

myname="$(basename "$0")"
timestamp="$(date '+%y%m%d')"
thisyear="$(date '+%Y')"
year="$thisyear"

function usage() {
    >&2 echo "
Usage:   $myname [-diklv] [-P working_parentdir] [-y year] -r refdir_pattern
         $myname [-diklv] [-P working_parentdir] [-y year] -R 
         $myname -h

            to fake consistence of the ctcs2-generated  \"rpmlist\", resp.,
            \"hwinfo\" files throughout the subdirectories

                  *-$year-*

            of the directory specified in the -P option (default: \$PWD).
            The files to fake are going to be symlinked to the equally-named
            file in the reference subdirectory.
            The original files are renamed  to *-HIDDEN-\$something.

            Purpose of this script: workaround for bnc#560428.
            Return values:
		1 in case of errors
		2 if a dry run (without -R) detects needed faking
		0 otherwise.

Options:
         -h   Only print this help text and exit successfully.
         -d   Dry run: do nothing, just report the commands that would
              be executed
         -i   Fake consistent hwinfo files
         -k   Fake consistent kernel files (reckless)
         -l   Fake consistent rpmlist files
         -P   specify the parent directory of the working dirs.
         -R   Revert fake (provided the *-HIDDEN files are unique)
         -r   Specify a shell pattern for the reference subdir.
              The final pattern is supposed to be

              *refdir_pattern*-${year}-*

         -v   Be more verbose 
         -y   Override the autodetected year part in the dirnames
              (default: $thisyear). The optarg may be an (appropriately
              quoted) shell pattern.
"
}

#   =====   Evaluate and check the commandline  ======= #
#                                                       #
dryrun=""
reference=""
revert=""
workparentd="$PWD"
fake_hwinfo=""
fake_kernel=""
fake_rpmlist=""
verbose=""
while getopts hdiklP:Rr:vy: optchar ; do
    case "$optchar" in

      h)      usage
              exit 0			;;
      d)      dryrun=yes		;;
      i)      fake_hwinfo=yes		;;
      k)      fake_kernel=yes		;;
      l)      fake_rpmlist=yes		;;
      P)      workparentd="$OPTARG"	;;
      R)      revert=yes		;;
      r)      reference="$OPTARG"	;;
      v)      verbose="-v"		;;
      y)      year="$OPTARG"		;;
      *)      usage
              exit 1			;; 
    esac
done
shift $((OPTIND - 1))
#                                                       #
#   =====   Evaluate and check the commandline  ======= #

if [ -d "$workparentd" -a  -r "$workparentd" -a  -w "$workparentd" -a  -x "$workparentd" ] ; then
		[ "$verbose" ] && echo "pushd to $workparentd..."
		pushd "$workparentd" >/dev/null 2>&1
else
		echo "\
ERROR: option -P: $wprkparentd: not a drwx directory
Giving up..." >&2
		exit 1
fi

if [ "$revert" != "yes" ] ; then
	refdir="$(echo *"$reference"*-$year-*)"
	if ! [ -d "$refdir" -a  -r "$refdir" -a  -w "$refdir" -a  -x "$refdir" ] ; then
		echo "\
ERROR: option -r: invalid reference. Found \"$refdir\": not a drwx directory
Giving up..." >&2
		exit 1
	fi
else
	refdir=""
fi	# [ "$revert" != "yes" ]

need_fake="0"	# for reporting after a dry run
to_fake=""
[ "$fake_hwinfo" == "yes" ] && to_fake="$to_fake hwinfo"
[ "$fake_kernel" == "yes" ] && to_fake="$to_fake kernel"
[ "$fake_rpmlist" == "yes" ] && to_fake="$to_fake rpmlist"

for d in $(echo *-$year-*) ; do
	[ -d "$d" ] || continue
	[ "$d" == "$refdir" ] &&  continue
	for f in $to_fake ; do
		ff="$d/$f"
		ff_hidden="$ff"-HIDDEN
		if [ "$revert" == "yes" ] ; then
			ff_hidden="$(shopt -s nullglob; echo "$ff_hidden"*)"
			if [ -z "$ff_hidden" ] ; then
				echo "INFO:    \"$ff\": no associated HIDDEN file found for reverting. SKIPPED." >&2
				continue	# next "$f"
			elif ! [ -L "$ff" -a -f "$ff_hidden" ] ; then
				echo "WARNING: Unable to revert from hidden: \"$ff_hidden\" to \"$ff\". SKIPPED." >&2
				continue	# next "$f"
			fi
			if [ "$dryrun" == "yes" ] ; then
				echo "DRY RUN:  rm $verbose \"$ff\" && mv $verbose \"$ff_hidden\" \"$ff\""
			else
				rm $verbose "$ff" && mv $verbose "$ff_hidden" "$ff"
			fi	# if [ "$dryrun" == "yes" ]	
		else
			if [ -e "$ff_hidden" ] ; then
				ff_hidden="$ff_hidden"."$$"
				if [ -e "$ff_hidden" ] ; then
					echo "WARNING: $ff_hidden: File exists. SKIPPING..." >&2
					continue	# next "$f"
				fi
				echo "WARNING: $ff: multiple HIDDEN files, no autorevert will be possible" >&2
			fi
			# Faking needed?
			if cmp -s "$ff" "$refdir"/"$f" ; then
				[ -n "$verbose" ] && echo "NOTICE: $ff: identical to $refdir/$f: SKIPPED" >&2 
				continue
			fi
			# Yes it is :-/
			if [ "$dryrun" == "yes" ] ; then
				need_fake="2"	# for reporting after dry run
				echo "DRY RUN:  mv $verbose \"$ff\" \"$ff_hidden\" && ln -s  $verbose ../\"$refdir\"/\"$f\" \"$ff\""
			else
				mv $verbose "$ff" "$ff_hidden" && ln -s  $verbose ../"$refdir"/"$f" "$ff"
			fi	# if [ "$dryrun" == "yes" ]	
		fi
	done  # f in $to_fake 
done # d in $(echo *-$year-*)

[ "$verbose" ] && echo "popd to old \$PWD..."
popd >/dev/null 2>&1
exit "$need_fake"
