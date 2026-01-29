# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          the RSA operations.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298, poo#195065

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';

sub rsa_decrypt {
    my $test_dir = "tpm2_engine_rsa_decrypt";
    my $data_file = "$test_dir/data";
    my $key_file = "$test_dir/mykey";
    my $enc_file = "$test_dir/mycipher";
    my $openssl_opts = is_sle(">=15-SP6") ? "-pkeyopt rsa_padding_mode:oaep" : "";
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "echo tpm2test > $data_file";
    assert_script_run "tpm2tss-genkey -a rsa -s 2048 $key_file";
    assert_script_run "openssl rsa -engine tpm2tss -inform engine -in $key_file -pubout -outform pem -out $key_file.pub";
    assert_script_run "openssl pkeyutl $openssl_opts -pubin -inkey $key_file.pub -in $data_file -encrypt -out $enc_file";
    assert_script_run "openssl pkeyutl $openssl_opts -engine tpm2tss -keyform engine -inkey $key_file -decrypt -in $enc_file -out $data_file.decrypt";
    assert_script_run "diff $data_file $data_file.decrypt";
}

sub rsa_sign {
    my $test_dir = "tpm2_engine_rsa_sign";
    my $test_file = "$test_dir/data";
    my $key_file = "$test_dir/mykey";
    my $sig_file = "$test_dir/mysig";
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "echo tpm2test > $test_file";
    assert_script_run "tpm2tss-genkey -a rsa -s 2048 $key_file";
    assert_script_run "openssl rsa -engine tpm2tss -inform engine -in $key_file -pubout -outform pem -out $key_file.pub";
    assert_script_run "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $key_file -sign -in $test_file -out $sig_file";
    validate_script_output("openssl pkeyutl -pubin -inkey $key_file.pub -verify -in $test_file -sigfile $sig_file", sub { /Signature\s+Verified\s+Successfully/ });
}

sub run {
    select_serial_terminal;
    rsa_decrypt;
    rsa_sign;
}

1;
