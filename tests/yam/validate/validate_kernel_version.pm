# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate the kernel version of the installed system.

# Summary: Validate the kernel version of the installed system.
# Compare the output of "uname -r" with the kernel version from test data.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':assert';

sub run {
    select_console 'root-console';

    my $expected = get_test_suite_data()->{kernel_version}
      or die 'Missing "kernel_version" in test data';
    my $kernel = script_output('uname -r');

    assert_matches(qr/^\Q$expected\E/, $kernel,
        "Wrong kernel version. Expected prefix: '$expected', got '$kernel'");
}

1;
