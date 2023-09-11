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
use strict;
use warnings;
use utils;
use version_utils qw(is_sle is_transactional is_sle_micro);
use Utils::Architectures qw(is_s390x);

sub run {
    select_serial_terminal;

    # openssl pre-installed in SLE Micro
    zypper_call 'in openssl' unless is_transactional;

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
    push @invalid_cipher, "des-ede" if is_sle('12-SP2+');
    # des3 des-ede3 were reporting failure in SLE Micro 5.4 (see # https://bugzilla.suse.com/show_bug.cgi?id=1209271#c8),
    # but in 5.5 behaviour is different, possible cause:
    # (1) different worker used z13 vs linuxone (2) or libica not correctly activated
    # In any case with normal s390x kvm worker we don't need to exclude them anymore.
    for my $cipher (@invalid_cipher) {
        validate_script_output
          "openssl enc -$cipher -e -pbkdf2 -in $file_raw -out $file_enc -k $enc_passwd -md $hash_alg 2>&1 || true",
          sub { m/disabled for fips|disabled for FIPS|unknown option|Unknown cipher|enc: Unrecognized flag|unsupported:crypto|request failed/ };
    }

    script_run 'cd - && rm -rf fips-test';
}

1;
