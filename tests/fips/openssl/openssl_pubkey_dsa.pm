# OpenSSL FIPS test
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Test description: Verify openssl could generate DSA public key pair
# and succeed to sign/verify message.
# According to FIPS 186-4, approved DSA key sizes: 1024/2048/3072
#
# Package: openssl
# Summary: Add RSA/DSA public key tests for openssl-fips
#          For RSA public key, test 2048/3072/4096 bits key pair generation,
#          file encrypt/decrypt and message signing/verification.
#
#          For DSA public key, test 1024/2048/3072 bits key pair generation,
#          and message signing/verification.
#          By openssl-1.1.0-fips.patch, remove 1024 bits DSA keysize generate check in fips mode
#
#          According to openssl wiki, "dss1" digest method is not available in openssl-1.1-x any more
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#47471, poo#48020

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_transactional is_sle is_sle_micro is_tumbleweed);
use security::openssl_misc_utils;

sub run_fips_dsa_tests {
    my $openssl_binary = shift // "openssl";
    my $file_raw = "hello.txt";
    my $dgst_alg = "sha256";
    my $file_dgt = $file_raw . ".$dgst_alg";
    my $file_sig = $file_dgt . ".sig";
    my @dsa_key_sizes = (2048, 3072);

    my $openssl_version = get_openssl_x_y_version("$openssl_binary");
    record_info("VERSION: $openssl_version");

    # DSA operations are expected to fail on 15-SP6+ and SLE Micro 6.0+ in FIPS mode with OpenSSL 3 (poo#161891)
    my $expect_failure = ((is_sle('>=15-SP6') || is_sle_micro('>=6.0') || is_tumbleweed) && check_var('FIPS_ENABLED', '1')) && ($openssl_version >= "3.0") ? 1 : 0;

    # Prepare temp directory and file for testing
    assert_script_run "mkdir fips-test && cd fips-test && echo Hello > $file_raw";

    for my $size (@dsa_key_sizes) {
        # Generate dsa key pair
        my $dsa_prikey = "test-dsa-prikey-" . $size . ".pem";
        my $dsa_pubkey = "test-dsa-pubkey-" . $size . ".pem";

        my $ret_val = script_run("$openssl_binary dsaparam $size < /dev/random > dsaparam.pem", 200);
        if ($expect_failure) {
            if ($ret_val != 0) {
                # in FIPS mode on newer products DSA is not supported and should always fail
                record_info "$openssl_binary dsaparam is expected to fail in FIPS mode";
                next;
            } else {
                # in FIPS mode on newer products DSA is not supported and it should never work
                die "$openssl_binary dsaparam: expected FAIL, got PASSED.";
            }
        } else {
            # in FIPS mode on older products DSA should always work
            die "$openssl_binary dsaparam: expected PASS, got FAIL" if ($ret_val != 0);
        }

        assert_script_run "$openssl_binary gendsa -out $dsa_prikey dsaparam.pem";
        assert_script_run "$openssl_binary dsa -in $dsa_prikey -pubout -out $dsa_pubkey";

        # A source of random numbers is required for DSA, so get message digest first
        assert_script_run sprintf("$openssl_binary dgst -%s %s | awk '{print \$2}' > %s", $dgst_alg, $file_raw, $file_dgt);

        # Sign message digest with private key and verify signature with public key
        # openssl >= 1.1.x (sha256)
        # openssl >= 1.0.x (dss1)
        my $algo = ($openssl_version >= "1.1") ? "sha256" : "dss1";
        assert_script_run "$openssl_binary dgst -$algo -sign $dsa_prikey $file_dgt > $file_sig";

        my $digest_cmd = "$openssl_binary dgst -$algo -verify $dsa_pubkey -signature $file_sig $file_dgt";
        if ($expect_failure) {
            die "Expected failure but '$openssl_binary dsa' command succeeded" if (script_run $digest_cmd) == 0;
        } else {
            validate_script_output $digest_cmd, sub { m/Verified OK/ };
        }

        # Clean up temp files
        script_run "rm -f $file_dgt $file_sig dsaparam.pem";
    }

    script_run 'cd - && rm -rf fips-test';
}

sub run {
    select_serial_terminal;
    install_openssl;
    my $ver = get_openssl_full_version;
    record_info("Testing OpenSSL $ver");
    run_fips_dsa_tests;
    if (is_sle('>=15-SP6') && is_sle('<16')) {
        $ver = get_openssl_full_version(OPENSSL1_BINARY);
        record_info("Testing OpenSSL $ver");
        run_fips_dsa_tests(OPENSSL1_BINARY);
    }
}

sub test_flags {
    return {
        #poo160197 workaround since rollback seems not working with swTPM
        no_rollback => is_transactional ? 1 : 0,
        fatal => 1
    };
}

1;
