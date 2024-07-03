# openssl fips test
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Test description: In fips mode, openssl only works with the FIPS
# approved HASH algorithms: SHA1 and SHA2 (224, 256, 384, 512)
#
# Package: openssl
# Summary: Hash test cases for openssl-fips (system default openssl  package)
#
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils qw(zypper_call);
use version_utils qw(is_transactional);
use security::openssl_fips_hash_common;

sub install_pkg {
    # openssl pre-installed in SLE Micro
    zypper_call 'in openssl' unless is_transactional;
}

sub run {
    select_serial_terminal;
    install_pkg();
    run_fips_hash_tests();
}

sub test_flags {
    #poo160197 workaround since rollback seems not working with swTPM
    return {fatal => 0, always_rollback => is_transactional ? 0 : 1};
}

1;
