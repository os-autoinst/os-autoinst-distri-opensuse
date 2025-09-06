# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the extra kernel parameters added to bootloader section
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';
    my $output = script_output('cat /proc/cmdline');
    my ($parameters) = get_var('AGAMA_PROFILE_OPTIONS') =~ /bootloader_extra_kernel_params="([^"]*)"/;

    unless ($output =~ /\Q$parameters\E/) {
        die "$parameters not found in kernel command line!";
    }
}

1;
