# openssl1.1 fips test
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Test description: In fips mode, openssl only works with the FIPS
# approved HASH algorithms: SHA1 and SHA2 (224, 256, 384, 512)
#
# Package: openssl1.1
# Summary: Hash test cases for openssl-fips (legacy openssl 1.1 package)
#
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils qw(zypper_call);
use security::openssl_fips_hash_common;
use version_utils 'is_sle';
use registration 'add_suseconnect_product';


sub install_pkg {
    add_suseconnect_product('sle-module-legacy');
    zypper_call 'in openssl-1_1';
}

sub run {
    select_serial_terminal;
    return if is_sle('<15-SP6');
    install_pkg();
    my $openssl_bin = '/usr/bin/openssl-1_1';
    run_fips_hash_tests($openssl_bin);
}

sub test_flags {
    return {fatal => 0, always_rollback => 1};
}

1;
