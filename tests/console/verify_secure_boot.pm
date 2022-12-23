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
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

# The minimum number of octal digits in the efivars file should be 5,
# because the fifth octal digit shows whether Secure Boot is enabled (1) or disabled (0)
use constant MIN_OCTALS => 5;

sub run {
    my $test_data = get_test_suite_data();

    select_console 'root-console';
    record_info("Check file", "Check if file /sys/firmware/efi/efivars/SecureBoot-* exists");
    # From v6.0 kernel and onwards, the SecureBoot file resides in /sys/firmware/efi/efivars/
    assert_script_run("ls /sys/firmware/efi/efivars/SecureBoot-*");
    record_info("Check secure boot", "Check if secure boot option is set as expected");
    my $octal_str = script_output("od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-*");
    my @octal_array = split(/\s+/, $octal_str);

    die 'Unexpected values in Secure Boot file' unless 0 + @octal_array >= MIN_OCTALS && $octal_array[MIN_OCTALS - 1] =~ /0|1/;
    my $secure_boot = $octal_array[MIN_OCTALS - 1] ? 'enabled' : 'disabled';
    assert_equals($test_data->{secure_boot}, $secure_boot, "The secure boot option is not $test_data->{secure_boot}");
}

1;
