# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the extra kernel parameters added to bootloader section
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;

sub run {
    select_console 'root-console';

    get_var('AGAMA_PROFILE_OPTIONS') =~ /bootloader_extra_kernel_params="(?<kernel_params>.*)"/;

    my $output = script_output('cat /proc/cmdline');

    die "$+{kernel_params} not found in kernel command line!" unless $output =~ /$+{kernel_params}/;
}

1;
