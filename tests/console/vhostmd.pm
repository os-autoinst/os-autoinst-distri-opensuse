# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt vhostmd
# Summary: Simple vhostmd test
# - Install libvirt and vhostmd
# - Start libvirtd (and check status)
# - For vhostmd, start, check status, stop, check status again for errors, restart and
# check status one more time
# - Run "cat /dev/shm/vhostmd0" (if device exists)
# - Check system logs for vhostmd messages
# Maintainer: Jozef Pupava <jpupava@suse.com>

use warnings;
use base 'consoletest';
use strict;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl zypper_call);

sub run {
    my ($self) = @_;
    select_serial_terminal();
    zypper_call 'in libvirt vhostmd';

    # start libvirt hypervisor for vhostmd
    systemctl 'start libvirtd';
    systemctl 'status libvirtd';

    # start, stop, restart and check vhostmd
    systemctl 'start vhostmd';
    systemctl 'status vhostmd';
    systemctl 'stop vhostmd';
    systemctl 'status vhostmd || true';
    systemctl 'restart vhostmd';
    systemctl 'status vhostmd';
    # print /dev/shm/vhostmd0 if is not empty
    assert_script_run 'if [ -s /dev/shm/vhostmd0 ]; then cat /dev/shm/vhostmd0; else false; fi';
    assert_script_run 'journalctl -u vhostmd --no-pager';
}

sub post_run_hook {
    # stop started services
    systemctl 'stop vhostmd libvirtd';
}

1;
