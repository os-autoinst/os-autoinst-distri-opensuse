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
use Test::Assert ':assert';

sub run {
    select_console 'root-console';

    my $kernel = script_output('uname -r');

    assert_matches(qr/^.+-nvidia64kb$/, $kernel,
        "Wrong kernel version '. Got '$kernel'");
}

1;
