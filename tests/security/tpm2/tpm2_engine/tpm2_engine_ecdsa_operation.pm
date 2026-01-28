# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          ECDSA operations.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298, poo#195065

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';

sub run {
    select_serial_terminal;
    my $test_dir = "/tmp/tpm2_engine_ecdsa_sign";
    my $data_file = "$test_dir/data";
    my $key = "$test_dir/mykey";
    my $sig = "$test_dir/mysig";
    my $hash = "$test_dir/data.hash";
    my $openssl_opts = is_sle('<=15-SP5') ? "-engine tpm2tss -inform engine" : "-provider tpm2";
    assert_script_run "mkdir -p $test_dir";
    assert_script_run "echo tpm2test > $data_file";
    assert_script_run "tpm2tss-genkey -a ecdsa -s 2048 $key";
    assert_script_run "openssl ec $openssl_opts -in $key -pubout -outform pem -out $key.pub";
    assert_script_run "openssl dgst -sha256 -binary $data_file > $hash";
    assert_script_run "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $key -sign -in $hash -out $sig";
    validate_script_output("openssl pkeyutl -engine tpm2tss -keyform engine -inkey $key -verify -in $hash -sigfile $sig", sub { /Signature\s+Verified\s+Successfully/ });
}

1;
