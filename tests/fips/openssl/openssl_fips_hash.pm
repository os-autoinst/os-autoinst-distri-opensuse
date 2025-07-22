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
use version_utils qw(is_sle is_sle_micro is_transactional);
use security::openssl_misc_utils;

my $tmp_file = "/tmp/hello.txt";

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

sub run {
    select_serial_terminal;
    install_openssl;
    my $ver = get_openssl_full_version;
    record_info("Testing OpenSSL $ver");
    run_fips_hash_tests;
    if (is_sle('>=15-SP6') && is_sle('<16')) {
        $ver = get_openssl_full_version(OPENSSL1_BINARY);
        record_info("Testing OpenSSL $ver");
        run_fips_hash_tests(OPENSSL1_BINARY);
    }
}

sub test_flags {
    return {
        #poo160197 workaround since rollback seems not working with swTPM
        no_rollback => is_transactional ? 1 : 0,
        fatal => 0
    };
}

1;
