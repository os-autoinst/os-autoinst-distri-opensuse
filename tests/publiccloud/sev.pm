# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test AMD-SEV
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    # Skip this test run, unless defined to run
    unless (get_var("PUBLIC_CLOUD_CONFIDENTIAL_VM", 0)) {
        record_info("Skipping test", "PUBLIC_CLOUD_CONFIDENTIAL_VM is not set");
        return;
    }

    # Ensure we are running with activated AMD Memory encryption
    script_run('dmesg | grep SEV | head');
    my $message = "Memory Encryption Features active";
    assert_script_run("dmesg | grep SEV | grep '$message'", fail_message => "AMD-SEV not active on this instance");
}

1;
