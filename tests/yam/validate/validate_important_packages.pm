# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate if important packages form test_data are installed.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base 'consoletest';
use testapi;
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';
    my $error = 0;

    for my $package (@{get_test_suite_data()->{important_packages}}) {
        if (script_run("rpm -q $package")) {
            $error = 1;
            record_info("Problem", "Package $package is not installed.");
        }
    }
    if ($error)
    {
        die "One or more important packages are missing";
    }
}

1;
