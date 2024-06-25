# openssl fips test
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: openssl-fips common function for Hash test cases
#
# Maintainer: QE Security <none@suse.de>

package security::openssl_fips_hash_common;

use strict;
use warnings;
use testapi;

use base 'Exporter';

our $tmp_file = "/tmp/hello.txt";

our @EXPORT = 'run_fips_hash_tests';

# With FIPS approved HASH algorithms, openssl should work
sub test_approved_hash_algos {
    my $openssl_binary = shift;
    my @approved_hash = ("sha1", "sha224", "sha256", "sha384", "sha512");
    for my $hash (@approved_hash) {
        assert_script_run "$openssl_binary dgst -$hash $tmp_file";
    }
}

# With non-approved HASH algorithms, openssl will report failure
# Remove md2 and sha, and add rmd160 and md5-sha1 from invalid hash check in fips mode
sub test_invalid_hash_algos {
    my $openssl_binary = shift;
    my @invalid_hash = ("md4", "md5", "mdc2", "rmd160", "ripemd160", "whirlpool", "md5-sha1");
    for my $hash (@invalid_hash) {
        eval {
            validate_script_output "$openssl_binary dgst -$hash $tmp_file 2>&1 || true", sub { m/$hash is not a known digest|unknown option|Unknown digest|dgst: Unrecognized flag|disabled for FIPS|disabled for fips|unsupported:crypto/ };
        };
        if ($@) {
            record_soft_failure 'bsc#1193859';
            validate_script_output "$openssl_binary dgst -$hash $tmp_file 2>&1 || true", sub { m/disabled for fips|disabled for FIPS|unknown option|Unknown digest|dgst: Unrecognized flag|unsupported:crypto/ };
        }
    }
}

# entry point; run tests by default with system's openssl binary
# call with a parameter like "/usr/bin/openssl-1_1" to run test with other binaries
sub run_fips_hash_tests {
    my $openssl_binary = shift // "openssl";
    assert_script_run "echo Hello > $tmp_file";
    test_approved_hash_algos($openssl_binary);
    test_invalid_hash_algos($openssl_binary);
    script_run "rm -f $tmp_file";
}

1;
