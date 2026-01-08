# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify that "resume=" kernel parameter is absent in the list of default parameters.
# This kernel parameter enables hibernation, it is not supported for all backends.
# See https://bugzilla.suse.com/show_bug.cgi?id=1188731

# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';
    my $is_present = get_test_suite_data()->{resume_kernel_param_present};
    my $grep_param = ($is_present eq '1') ? '' : '-v';
    my $error_msg = ($is_present eq '1') ? 'resume parameter not found' : 'resume parameter found';
    assert_script_run("grep $grep_param 'resume=' /proc/cmdline", fail_message => "$error_msg in /proc/cmdline");
}

1;
