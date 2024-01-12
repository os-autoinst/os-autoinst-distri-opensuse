# SUSE's openQA tests
#
# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: coreutils
# Summary: Verify that secure boot is set as expected.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use YaST::EFItools;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';


sub run {
    select_console 'root-console';
    my $test_data = get_test_suite_data();
    my $secure_boot = read_secure_boot_status;
    assert_equals($test_data->{secure_boot}, $secure_boot, "The secure boot option is not $test_data->{secure_boot}");
}

1;
