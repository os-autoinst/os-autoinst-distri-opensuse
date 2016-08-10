#!/bin/bash
#
#    Load generator for kGraft guests, to run simultaneously with a Live Patching
#

# Needed RPMs
for pkg in qa_lib_ctcs2 qa_test_ltp qa_test_newburn ; do
	if ! rpm -q "$pkg" ; then
		echo "ERROR: NEEDED RPM not installed. Aborting..." >&2
		exit 1
	fi	# if ! rpm -q "$pkg" ; then
done

cat /usr/share/qa/qa_test_ltp/tcf/syscalls.tcf \
    /usr/share/qa/qa_test_ltp/tcf/syscalls.tcf \
  > /usr/share/qa/qa_test_ltp/tcf/syscalls_twice.tcf

#  Reduced version of newburn, essentially KCOMPILE
#
mkdir -pv /usr/share/qa/qa_test_newburn/tcf
echo "\
#
# Reduced newburn for run during Live Patching
#
timer 2h
# System Information first
fg 1 INFO qa_test_newburn/info_linux
# and the tests...
bg 0 VMSTAT qa_test_newburn/vmstat-wrapper
bg 0 HEARTBEAT qa_test_newburn/timestamp
bg 0 KCOMPILE qa_test_newburn/kernel 8 /home/tmplinux
wait
exit" >/usr/share/qa/qa_test_newburn/tcf/newburn.tcf

# LTP: the syscalls tests
screen -S LTP_syscalls     -L -d -m /usr/lib/ctcs2/tools/run /usr/share/qa/qa_test_ltp/tcf/syscalls_twice.tcf
# Simultaneously: newburn
screen -S newburn_KCOMPILE -L -d -m /usr/lib/ctcs2/tools/run /usr/share/qa/qa_test_newburn/tcf/newburn.tcf

echo "Done. Continuing work in two detached screen sessions: \"LTP_syscalls\" and \"newburn_KCOMPILE\""
echo "
REMINDER: run heavy_load--tidyup.sh after these tests have run to completion
          in order to clear up /var/log/qa/ctcs2"
