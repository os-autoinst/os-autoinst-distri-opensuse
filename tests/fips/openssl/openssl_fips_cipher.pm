# openssl fips test
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: openssl
# Summary: FIPS: openssl_fips_cipher
#          In fips mode, openssl only works with the FIPS
#          approved Cihper algorithms: AES and DES3
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44837

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use version_utils qw(is_sle is_sle_micro);

sub run {
    select_serial_terminal;

    # openssl pre-installed in SLE Micro
    zypper_call 'in openssl' unless is_sle_micro;

    my $enc_passwd = "pass1234";
    my $hash_alg = "sha256";
    my $file_raw = "hello.txt";
    my $file_enc = "hello.txt.enc";
    my $file_dec = "hello.txt.tmp";

    # Prepare temp directory and file for testing
    assert_script_run "mkdir fips-test && cd fips-test && echo Hello > $file_raw";

    # With FIPS approved Cipher algorithms, openssl should work
    my @approved_cipher = ("aes128", "aes192", "aes256", "des3", "des-ede3");
    for my $cipher (@approved_cipher) {
        assert_script_run "openssl enc -$cipher -e -pbkdf2 -in $file_raw -out $file_enc -k $enc_passwd -md $hash_alg";
        assert_script_run "openssl enc -$cipher -d -pbkdf2 -in $file_enc -out $file_dec -k $enc_passwd -md $hash_alg";
        validate_script_output "cat $file_dec", sub { m/^Hello$/ };
        script_run "rm -f $file_enc $file_dec";
    }

    # With FIPS non-approved Cipher algorithms, openssl shall report failure
    my @invalid_cipher = ("bf", "cast", "rc4", "seed", "des", "desx");
    if (is_sle('12-SP2+')) {
        push @invalid_cipher, "des-ede";
    }
    for my $cipher (@invalid_cipher) {
        validate_script_output
          "openssl enc -$cipher -e -pbkdf2 -in $file_raw -out $file_enc -k $enc_passwd -md $hash_alg 2>&1 || true",
          sub { m/disabled for fips|disabled for FIPS|unknown option|Unknown cipher|enc: Unrecognized flag/ };
    }

    script_run 'cd - && rm -rf fips-test';
}

1;
