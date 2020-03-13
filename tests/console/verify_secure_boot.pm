# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify that secure boot is set as expected.
# Maintainer: Sofia Syrianidou <ssyrianidou@suse.com>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub run {
    my $test_data = get_test_suite_data();
    select_console 'root-console';
    record_info("Check file", "Check if file /sys/firmware/efi/vars/SecureBoot-*/data exists");
    assert_script_run("ls /sys/firmware/efi/vars/SecureBoot-*/data");
    record_info("Check secure boot", "Check if secure boot option is set as expected");
    my $secure_boot = script_output("od -An -t u1 /sys/firmware/efi/vars/SecureBoot-*/data") ? 'enabled' : 'disabled';
    assert_equals($test_data->{secure_boot}, $secure_boot, "The secure boot option is not $test_data->{secure_boot}");
}

1;


