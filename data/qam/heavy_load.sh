#!/bin/bash
#
#    Load generator for kGraft guests, to run simultaneously with a Live Patching
#

# Needed RPM
if ! rpm -q "ltp-stable" ; then
	echo "ERROR: NEEDED RPM not installed. Aborting..." >&2
	exit 1
fi

# Copy syscalls runtest file and use only new file
cp /opt/ltp/runtest/syscalls /opt/ltp/runtest/syscalls.klp
# disable add_key02 test - on most kernels causes panic
sed  -i '/\n/!N;/\n.*\n/!N;/\n.*\n.*add_key02/{$d;N;N;d};P;D' /opt/ltp/runtest/syscalls.klp
# kernel 4.4.92 ppc64le panicked with this tes
sed  -i '/\n/!N;/\n.*\n/!N;/\n.*\n.*add_key04/{$d;N;N;d};P;D' /opt/ltp/runtest/syscalls.klp

# LTP: the syscalls tests
screen -S LTP_syscalls     -L -d -m  sh -c 'yes | /opt/ltp/runltp  -f syscalls.klp'
# Simultaneously: newburn
screen -S LTP_aiodio_part4 -L -d -m  sh -c 'yes | /opt/ltp/runltp  -f ltp-aiodio.part4'

echo "Done. Continuing work in two detached screen sessions: \"LTP_syscalls\" and \"LTP_aiodio_part4\""
