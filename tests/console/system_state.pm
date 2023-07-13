# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary:  Export the existing status of running tasks and system load
# for future reference
# - Collect running process list
# - Collect system load average
# - Upload the gatherings to the job's logs
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use Utils::Backends;
use Utils::Architectures;
use strict;
use warnings;
use Utils::Logging 'tar_and_upload_log';

sub run {
    my ($self) = shift;
    is_ipmi ? use_ssh_serial_console : select_console 'root-console';
    my $timeout = is_s390x ? '90' : '30';
    script_run("mkdir /tmp/system_state", timeout => $timeout);
    script_run "ps axf > /tmp/system_state/psaxf.log";
    script_run "cat /proc/loadavg > /tmp/system_state/loadavg_consoletest_setup.txt";
    tar_and_upload_log('/tmp/system_state', '/tmp/stats_during_installation.tar.bz2');
}

1;
