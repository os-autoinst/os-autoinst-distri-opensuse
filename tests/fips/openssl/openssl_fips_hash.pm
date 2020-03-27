# openssl fips test
#
# Copyright © 2016-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Test description: In fips mode, openssl only works with the FIPS
# approved HASH algorithms: SHA1 and SHA2 (224, 256, 384, 512)
#
# Summary: Add Hash and Cipher test cases for openssl-fips
#          A new test suite "core" is created, which contains all the basic
#          test cases for fips verificaton when FIPS_ENABLED is set, like
#          the cases to verify opessl hash, cipher, or public key algorithms
#
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: poo#44834, poo#64649, poo#64842

use base "consoletest";
use testapi;
use strict;
use warnings;

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
    # Remove md2 and sha, and add rmd160 and md5-sha1 from invalid hash check in fips mode
    my @invalid_hash = ("md4", "md5", "mdc2", "rmd160", "ripemd160", "whirlpool", "md5-sha1");
    for my $hash (@invalid_hash) {
        validate_script_output "openssl dgst -$hash $tmp_file 2>&1 || true", sub { m/disabled for fips|disabled for FIPS|unknown option|Unknown digest|dgst: Unrecognized flag/ };
    }

    script_run 'rm -f $tmp_file';
}

1;
