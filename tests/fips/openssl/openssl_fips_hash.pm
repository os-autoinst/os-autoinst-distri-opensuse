# openssl fips test
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Test description: In fips mode, openssl only works with the FIPS
# approved HASH algorithms: SHA1 and SHA2 (224, 256, 384, 512)

# Summary: Add Hash and Cipher test cases for openssl-fips
#    A new test suite is created for FIPS_TS, named "core", which will
#    contain all the basic test cases for fips verificaton. Just like
#    the cases to verify opessl hash, cipher, or public key algorithms
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use testapi;
use strict;

sub run {
    select_console 'root-console';

    my $tmp_file = "/tmp/hello.txt";

    # Prepare temp file for testing
    assert_script_run "echo Hello > $tmp_file";

    # With FIPS approved HASH algorithms, openssl should work
    my @approved_hash = ("sha1", "sha224", "sha256", "sha384", "sha512");
    for my $hash (@approved_hash) {
        assert_script_run "openssl dgst -$hash $tmp_file";
    }

    # With non-approved HASH algorithms, openssl will report failure
    my @invalid_hash = ("md4", "md5", "mdc2", "ripemd160", "whirlpool", "sha");
    for my $hash (@invalid_hash) {
        validate_script_output "openssl dgst -$hash $tmp_file 2>&1 || true", sub { m/disabled for fips|unknown option/ };
    }

    script_run 'rm -f $tmp_file';
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
