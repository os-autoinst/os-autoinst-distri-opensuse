# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Get useful text-based information from the system and upload it as a log.
#          For more information regarding the collected data, check data/textinfo
# - Run script /root/data/textinfo, collecting the folling data
#   - Kernel version
#   - Loaded modules
#   - Memory information
#   - Fstab entries
#   - Mounted filesystems
#   - Free space
#   - Ip address (ipv4/ipv6), routes
#   - DNS info
#   - Network files
#   - List of kernel packages
#   - Current display manager
#   - Current window manager
#   - Ntp files (if any)
#   - /var/log/messages size (if any)
#   - Running processes
#   - System services
#   - Installed package list
#   - System logs
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

# have various useful general info included in videos
sub run {
    my ($self) = @_;
    select_serial_terminal;
    assert_script_run('curl -O ' . data_url('textinfo'));
    assert_script_run('chmod +x textinfo');
    assert_script_run("./textinfo 2>&1 | tee /tmp/info.txt", 150);
    upload_logs("/tmp/info.txt");
    upload_logs("/tmp/logs.tar.bz2");
    assert_script_run('rm textinfo');
}

1;
