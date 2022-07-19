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
# Disable add_key* tests (may cause crashes on older kernels)
# Disable tests which load custom kernel modules
grep -v 'module\|add_key' /opt/ltp/runtest/syscalls >/opt/ltp/runtest/syscalls.klp

# LTP: the syscalls tests
screen -S LTP_syscalls     -L -d -m  sh -c 'yes | /opt/ltp/runltp  -f syscalls.klp'
# Simultaneously: newburn
screen -S LTP_aiodio_part4 -L -d -m  sh -c 'yes | /opt/ltp/runltp  -f ltp-aiodio.part4'

echo "Done. Continuing work in two detached screen sessions: \"LTP_syscalls\" and \"LTP_aiodio_part4\""
