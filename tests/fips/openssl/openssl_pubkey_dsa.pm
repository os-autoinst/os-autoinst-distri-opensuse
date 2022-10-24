# openssl fips test
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
use strict;
use warnings;

sub run {
    select_serial_terminal;

    my $file_raw = "hello.txt";
    my $dgst_alg = "sha256";
    my $file_dgt = $file_raw . ".$dgst_alg";
    my $file_sig = $file_dgt . ".sig";
    my @dsa_key_sizes = (2048, 3072);

    # Add the openssl version check
    my $openssl_version_output = script_output("openssl version | awk '{print $2}'");
    my ($openssl_version) = $openssl_version_output =~ /(\d\.\d)/;

    # Prepare temp directory and file for testing
    assert_script_run "mkdir fips-test && cd fips-test && echo Hello > $file_raw";

    for my $size (@dsa_key_sizes) {
        # Generate dsa key pair
        my $dsa_prikey = "test-dsa-prikey-" . $size . ".pem";
        my $dsa_pubkey = "test-dsa-pubkey-" . $size . ".pem";
        assert_script_run "openssl dsaparam $size < /dev/random > dsaparam.pem", 200;
        assert_script_run "openssl gendsa -out $dsa_prikey dsaparam.pem";
        assert_script_run "openssl dsa -in $dsa_prikey -pubout -out $dsa_pubkey";

        # A source of random numbers is required for DSA, so get message digest first
        assert_script_run "openssl dgst -$dgst_alg $file_raw | awk '{print $2}' > $file_dgt";

        # Sign message digest with private key and verify signature with public key
        # openssl >= 1.1.x (sha256)
        # openssl >= 1.0.x (dss1)
        my $algo = ($openssl_version >= "1.1") ? "sha256" : "dss1";

        assert_script_run "openssl dgst -$algo -sign $dsa_prikey $file_dgt > $file_sig";
        validate_script_output "openssl dgst -$algo -verify $dsa_pubkey -signature $file_sig $file_dgt", sub { m/Verified OK/ };

        # Clean up temp files
        script_run "rm -f $file_dgt $file_sig dsaparam.pem";
    }

    script_run 'cd - && rm -rf fips-test';
}

1;
