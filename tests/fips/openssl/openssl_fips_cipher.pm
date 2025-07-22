# openssl fips test
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: openssl
# Summary: FIPS: openssl_fips_cipher
#          In fips mode, openssl only works with the FIPS
#          approved Cipher algorithms: AES and DES3
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44837, bsc#1209271, poo#134321

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_sle_micro is_transactional is_tumbleweed);
use security::openssl_misc_utils;

sub run_fips_cipher_tests {
    my $openssl_binary = shift // "openssl";

    my $enc_passwd = "pass1234";
    my $hash_alg = "sha256";
    my $file_raw = "hello.txt";
    my $file_enc = "hello.txt.enc";
    my $file_dec = "hello.txt.tmp";

    # Prepare temp directory and file for testing
    assert_script_run "mkdir fips-test && cd fips-test && echo Hello > $file_raw";

    # With FIPS approved Cipher algorithms, openssl should work
    my @approved_cipher = ("aes128", "aes192", "aes256");
    push @approved_cipher, qw(des3 des-ede3) unless has_default_openssl3;
    for my $cipher (@approved_cipher) {
        assert_script_run "$openssl_binary enc -$cipher -e -pbkdf2 -in $file_raw -out $file_enc -k $enc_passwd -md $hash_alg";
        assert_script_run "$openssl_binary enc -$cipher -d -pbkdf2 -in $file_enc -out $file_dec -k $enc_passwd -md $hash_alg";
        validate_script_output "cat $file_dec", sub { m/^Hello$/ };
        script_run "rm -f $file_enc $file_dec";
    }

    # With FIPS non-approved Cipher algorithms, openssl shall report failure
    my @invalid_cipher = ("bf", "cast", "des-ede", "rc4", "seed", "des", "desx");
    # des3 des-ede3 were reporting failure in SLE Micro 5.4 (see # https://bugzilla.suse.com/show_bug.cgi?id=1209271#c8),
    # but in 5.5 behaviour is different, possible cause:
    # (1) different worker used z13 vs linuxone (2) or libica not correctly activated
    # In any case with normal s390x kvm worker we don't need to exclude them anymore.
    for my $cipher (@invalid_cipher) {
        validate_script_output
          "$openssl_binary enc -$cipher -e -pbkdf2 -in $file_raw -out $file_enc -k $enc_passwd -md $hash_alg 2>&1 || true",
          sub { m/disabled for fips|disabled for FIPS|unknown option|Unknown cipher|enc: Unrecognized flag|unsupported:crypto|request failed/ };
    }

    script_run 'cd - && rm -rf fips-test';
}

sub run {
    select_serial_terminal;
    install_openssl;
    my $ver = get_openssl_full_version;
    record_info("Testing OpenSSL $ver");
    run_fips_cipher_tests;
    if (is_sle('>=15-SP6') && is_sle('<16')) {
        $ver = get_openssl_full_version(OPENSSL1_BINARY);
        record_info("Testing OpenSSL $ver");
        run_fips_cipher_tests(OPENSSL1_BINARY);
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
