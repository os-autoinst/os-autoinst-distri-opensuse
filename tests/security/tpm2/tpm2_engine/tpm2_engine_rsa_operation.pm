# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          the RSA operations.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # RSA operations
    # RSA decrypt
    my $test_enc_dir = "tpm2_engine_rsa_decrypt";
    my $test_file = "mydata";
    my $rsa_key = "mykey";
    my $enc_file = "mycipher";
    assert_script_run "mkdir $test_enc_dir";
    assert_script_run "cd $test_enc_dir";
    assert_script_run "echo tpm2test > $test_file";
    assert_script_run "tpm2tss-genkey -a rsa -s 2048 $rsa_key";
    assert_script_run "openssl rsa -engine tpm2tss -inform engine -in $rsa_key -pubout -outform pem -out $rsa_key.pub";
    assert_script_run "openssl pkeyutl -pubin -inkey $rsa_key.pub -in $test_file -encrypt -out $enc_file";
    assert_script_run "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $rsa_key -decrypt -in $enc_file -out $test_file.decrypt";
    assert_script_run "diff $test_file $test_file.decrypt";
    assert_script_run "cd";

    # RSA sign
    my $test_sign_dir = "tpm2_engine_rsa_sign";
    my $sig_file = "mysig";
    assert_script_run "mkdir $test_sign_dir";
    assert_script_run "cd $test_sign_dir";
    assert_script_run "echo tpm2test > $test_file";
    assert_script_run "tpm2tss-genkey -a rsa -s 2048 $rsa_key";
    assert_script_run "openssl rsa -engine tpm2tss -inform engine -in $rsa_key -pubout -outform pem -out $rsa_key.pub";
    assert_script_run "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $rsa_key -sign -in $test_file -out $sig_file";
    validate_script_output "openssl pkeyutl -pubin -inkey $rsa_key.pub -verify -in $test_file -sigfile $sig_file", sub { m/Signature\sVerified\sSuccessfully/ };
    assert_script_run "cd";
}

1;
