# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the kernel param of processor.max_cstate=1
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';
    my $output = script_output('cat /proc/cmdline');
    unless ($output =~ /processor\.max_cstate=1/) {
        die "processor.max_cstate=1 not found in kernel command line!";
    }
    record_info('Kernel Param', 'processor.max_cstate=1 is present');
}

1;
