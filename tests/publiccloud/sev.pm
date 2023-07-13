# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test AMD-SEV
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle);

# Get the version dependend dmesg message for secure virtualization on confidential compute
sub get_sev_message {
    return "AMD Secure Encrypted Virtualization (SEV) active" if is_sle('=15-SP2');
    # More messages will be added pas a pas, as more versions run this test.
    return "Memory Encryption Features active";    # Default message
}

sub run {
    select_serial_terminal;

    # Skip this test run, unless defined to run
    unless (get_var("PUBLIC_CLOUD_CONFIDENTIAL_VM", 0)) {
        record_info("Skipping test", "PUBLIC_CLOUD_CONFIDENTIAL_VM is not set");
        return;
    }

    # Ensure we are running with activated AMD Memory encryption
    script_run('dmesg | grep SEV | head');
    my $message = get_sev_message();
    assert_script_run("dmesg | grep SEV | grep '$message'", fail_message => "AMD-SEV not active on this instance");
}

1;
