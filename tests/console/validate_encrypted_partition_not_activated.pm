# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validation module to check that partition is not activated.
# Covered scenarios:
# - Validate that hard disk encryption(LUKS) is not activated on the configured partitioning
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "installbasetest";
use scheduler 'get_test_suite_data';
use testapi;
use validate_encrypt_utils;
use Utils::Backends 'use_ssh_serial_console';

sub run {
    my $enc_disk_part = get_test_suite_data()->{enc_disk_part};
    select_console 'install-shell';
    verify_locked_encrypted_partition($enc_disk_part);
    select_console 'installation';
}

1;
