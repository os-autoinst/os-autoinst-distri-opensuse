# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Per TPM2 stack, we would like to add the tpm2-tss-engine,
#          For tpm2_enginee tests, we need tpm2-abrmd serive active.
#          We have several test modules, this test module will cover
#          ECDSA operations.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64902, tc#1742298

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    select_serial_terminal;

    # ECDSA operations
    # There is an known issue bsc#1159508
    # Please use the command below to carry out the tests
    my $test_dir = "tpm2_engine_ecdsa_sign";
    my $test_file = "data";
    my $my_key = "mykey";
    my $my_sig = "mysig";
    assert_script_run "mkdir $test_dir";
    assert_script_run "cd $test_dir";
    assert_script_run "echo tpm2test > $test_file";
    assert_script_run "tpm2tss-genkey -a ecdsa -s 2048 $my_key";
    assert_script_run "openssl ec -engine tpm2tss -inform engine -in $my_key -pubout -outform pem -out $my_key.pub";
    assert_script_run "sha256sum $test_file | cut -d ' ' -f 1 | base64 -d > $test_file.hash";
    assert_script_run "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $my_key -sign -in $test_file.hash -out $my_sig";
    validate_script_output "openssl pkeyutl -engine tpm2tss -keyform engine -inkey $my_key -verify -in $test_file.hash -sigfile $my_sig", sub {
        m
            /Signature\sVerified\sSuccessfully/
    };
    assert_script_run "cd";
}

1;
