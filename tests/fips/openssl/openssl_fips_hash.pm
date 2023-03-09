# openssl fips test
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Test description: In fips mode, openssl only works with the FIPS
# approved HASH algorithms: SHA1 and SHA2 (224, 256, 384, 512)
#
# Package: openssl
# Summary: Add Hash and Cipher test cases for openssl-fips
#          A new test suite "core" is created, which contains all the basic
#          test cases for fips verificaton when FIPS_ENABLED is set, like
#          the cases to verify opessl hash, cipher, or public key algorithms
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44834, poo#64649, poo#64842, poo#104184

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils qw(zypper_call);
use version_utils qw(is_transactional);

sub run {
    select_serial_terminal;

    # openssl pre-installed in SLE Micro
    zypper_call 'in openssl' unless is_transactional;

    my $tmp_file = "/tmp/hello.txt";

    # Prepare temp file for testing
    assert_script_run "echo Hello > $tmp_file";

    # With FIPS approved HASH algorithms, openssl should work
    my @approved_hash = ("sha1", "sha224", "sha256", "sha384", "sha512");
    for my $hash (@approved_hash) {
        assert_script_run "openssl dgst -$hash $tmp_file";
    }

    # With non-approved HASH algorithms, openssl will report failure
    # Remove md2 and sha, and add rmd160 and md5-sha1 from invalid hash check in fips mode
    my @invalid_hash = ("md4", "md5", "mdc2", "rmd160", "ripemd160", "whirlpool", "md5-sha1");
    for my $hash (@invalid_hash) {
        eval {
            validate_script_output "openssl dgst -$hash $tmp_file 2>&1 || true", sub { m/$hash is not a known digest|unknown option|Unknown digest|dgst: Unrecognized flag|disabled for FIPS|disabled for fips|unsupported:crypto/ };
        };
        if ($@) {
            record_soft_failure 'bsc#1193859';
            validate_script_output "openssl dgst -$hash $tmp_file 2>&1 || true", sub { m/disabled for fips|disabled for FIPS|unknown option|Unknown digest|dgst: Unrecognized flag|unsupported:crypto/ };
        }
    }

    script_run 'rm -f $tmp_file';
}

sub test_flags {
    return {fatal => 0, always_rollback => 1};
}

1;
