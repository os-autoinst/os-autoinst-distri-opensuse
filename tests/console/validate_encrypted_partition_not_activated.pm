# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Validation module to check that partition is inactive.
# Covered scenarios:
# - Validate that hard disk encryption(LUKS) is not activated on the configured partitioning
#
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use scheduler 'get_test_suite_data';
use testapi;
use validate_encrypt_utils;

sub run {
    my $test_data = get_test_suite_data();
    select_console 'install-shell';
    my $status = parse_cryptsetup_status($test_data->{mapped_device});
    verify_cryptsetup_message($test_data->{device_status}->{message}, $status->{message});
    select_console 'installation';
}

1;
