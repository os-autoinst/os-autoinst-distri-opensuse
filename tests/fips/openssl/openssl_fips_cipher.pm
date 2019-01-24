# openssl fips test
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: FIPS: In fips mode, openssl only works with the FIPS
#          approved Cihper algorithms: AES and DES3
#
# Original Author: Qingming Su <qingming.su@suse.com>
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: poo#44837

use base "consoletest";
use testapi;
use strict;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';

    my $enc_passwd = "pass1234";
    my $hash_alg   = "sha256";
    my $file_raw   = "hello.txt";
    my $file_enc   = "hello.txt.enc";
    my $file_dec   = "hello.txt.tmp";

    # Prepare temp directory and file for testing
    assert_script_run "mkdir fips-test && cd fips-test && echo Hello > $file_raw";

    # With FIPS approved Cipher algorithms, openssl should work
    my @approved_cipher = ("aes128", "aes192", "aes256", "des3");
    for my $cipher (@approved_cipher) {
        assert_script_run "openssl enc -$cipher -e -in $file_raw -out $file_enc -k $enc_passwd -md $hash_alg";
        assert_script_run "openssl enc -$cipher -d -in $file_enc -out $file_dec -k $enc_passwd -md $hash_alg";
        validate_script_output "cat $file_dec", sub { m/^Hello$/ };
        script_run "rm -f $file_enc $file_dec";
    }

    # With FIPS non-approved Cipher algorithms, openssl shall report failure
    my @invalid_cipher = ("bf", "cast5", "rc4", "seed", "des", "desx");
    if (is_sle('12-SP2+')) {
        push @invalid_cipher, "des-ede";
    }
    for my $cipher (@invalid_cipher) {
        validate_script_output
          "openssl enc -$cipher -e -in $file_raw -out $file_enc -k $enc_passwd -md $hash_alg 2>&1 || true",
          sub { m/disabled for fips|unknown option|Unknown cipher/ };
    }

    script_run 'cd - && rm -rf fips-test';
}

1;
