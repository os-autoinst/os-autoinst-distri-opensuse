# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test AMD-SEV
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
#use version_utils qw(is_sle is_opensuse is_leap is_tumbleweed);
#use registration qw(cleanup_registration register_product add_suseconnect_product get_addon_fullname remove_suseconnect_product);

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Skip this test run, unless defined to run
    unless (get_var("PUBLIC_CLOUD_CONFIDENTIAL_VM", 0)) {
        record_info("Skipping test", "PUBLIC_CLOUD_CONFIDENTIAL_VM is not set");
        return;
    }

    # Ensure we are running with activated AMD Memory encryption
    script_run('dmesg | grep SEV | head');
    assert_script_run('dmesg | grep SEV | grep "AMD Memory Encryption Features active"', fail_message => "AMD-SEV not active on this instance");
}

1;
