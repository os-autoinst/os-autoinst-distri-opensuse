# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validation module to check that previously encrypted partition is active.
# Covered scenarios:
# - Verify that activated during installation the existing encrypted partition is actually active;
# - Verify that all properties of the activated partition are correct (using 'cryptsetup status')
# encrypted volumes that encrypted volume is successfully activated during
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "installbasetest";
use scheduler 'get_test_suite_data';
use testapi;
use validate_encrypt_utils;

sub run {
    my $test_data = get_test_suite_data();
    validate_encrypted_volume_activation({
            mapped_device => $test_data->{mapped_device},
            device_status => $test_data->{device_status}->{message},
            properties => $test_data->{device_status}->{properties}
    });
}

1;
