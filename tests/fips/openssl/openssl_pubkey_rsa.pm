# openssl fips test
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Test description: Verify openssl could generate RSA public key pair
# and succeed to encrypt/decrypt/sign/verify message.
# According to FIPS 186-2, approved RSA key sizes: 2048/3072/4096

# Package: openssl
# Summary: Add RSA/DSA public key tests for openssl-fips
#    For RSA public key, test 2048/3072/4096 bits key pair generation,
#    file encrypt/decrypt and message signing/verification.
#
#    For DSA public key, test 1024/2048/3072 bits key pair generation,
#    and message signing/verification.
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use version_utils qw (is_sle is_sle_micro is_transactional package_version_cmp);
use security::openssl_misc_utils;

sub run_fips_rsa_tests {
    my $openssl_binary = shift // "openssl";
    my $file_raw = "hello.txt";
    my $file_enc = $file_raw . ".enc";
    my $file_dec = $file_raw . ".tmp";
    my $dgst_alg = "sha256";
    my $file_sig = $file_raw . ".$dgst_alg" . ".sig";
    my @rsa_key_sizes = (2048, 3072, 4096);

    # Prepare temp directory and file for testing
    assert_script_run "mkdir fips-test && cd fips-test && echo Hello > $file_raw";

    for my $size (@rsa_key_sizes) {
        # Generate rsa key pair
        my $rsa_prikey = "test-rsa-prikey-" . $size . ".pem";
        my $rsa_pubkey = "test-rsa-pubkey-" . $size . ".pem";
        assert_script_run "$openssl_binary genrsa -out $rsa_prikey $size", 200;
        assert_script_run "$openssl_binary rsa -in $rsa_prikey -pubout -out $rsa_pubkey";

        my $openssl_version = script_output("$openssl_binary version -v | awk '{print \$2}'");
        if (package_version_cmp($openssl_version, '3.0.0') > 0) {
            my $encrypt_cmd = "$openssl_binary pkeyutl -encrypt -in $file_raw -inkey $rsa_pubkey -pubin -out $file_enc";
            my $decrypt_cmd = "$openssl_binary pkeyutl -decrypt -in $file_enc -inkey $rsa_prikey -out $file_dec";
            # should fail without oaep padding and pass with oeap padding
            validate_script_output "$encrypt_cmd 2>&1", sub { m/(illegal or unsupported|invalid) padding mode/ }, proceed_on_failure => 1; # Encrypt with public key
            validate_script_output "$decrypt_cmd 2>&1", sub { m/(illegal or unsupported|invalid) padding mode/ }, proceed_on_failure => 1; # Decrypt with private key
            my $oaep_options = " -pkeyopt rsa_padding_mode:oaep";
            assert_script_run $encrypt_cmd . $oaep_options;    # Encrypt with public key
            assert_script_run $decrypt_cmd . $oaep_options;    # Decrypt with private key
        } else {
            # Encrypt with public key
            assert_script_run "$openssl_binary rsautl -encrypt -in $file_raw -inkey $rsa_pubkey -pubin -out $file_enc";
            # Decrypt with private key
            assert_script_run "$openssl_binary rsautl -decrypt -in $file_enc -inkey $rsa_prikey -out $file_dec";
        }

        validate_script_output "cat $file_dec", sub { m/^Hello$/ };

        # Sign message with private key
        assert_script_run "$openssl_binary dgst -$dgst_alg -sign $rsa_prikey -out $file_sig $file_raw";

        # Verify signature with public key
        validate_script_output "$openssl_binary dgst -$dgst_alg -verify $rsa_pubkey -signature $file_sig $file_raw", sub { m/Verified OK/ };

        # Clean up temp files
        script_run "rm -f $file_enc $file_dec $file_sig";
    }

    script_run 'cd - && rm -rf fips-test';
}

sub run {
    select_serial_terminal;
    install_openssl;
    my $ver = get_openssl_full_version;
    record_info("Testing OpenSSL $ver");
    run_fips_rsa_tests;
    if (is_sle('>=15-SP6') && is_sle('<16')) {
        $ver = get_openssl_full_version(OPENSSL1_BINARY);
        record_info("Testing OpenSSL $ver");
        run_fips_rsa_tests(OPENSSL1_BINARY);
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
