# openssl fips test
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Test description: Verify openssl could generate DSA public key pair
# and succeed to sign/verify message.
# According to FIPS 186-4, approved DSA key sizes: 1024/2048/3072

# Summary: Add RSA/DSA public key tests for openssl-fips
#    For RSA public key, test 2048/3072/4096 bits key pair generation,
#    file encrypt/decrypt and message signing/verification.
#
#    For DSA public key, test 1024/2048/3072 bits key pair generation,
#    and message signing/verification.
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use testapi;
use strict;
use warnings;

sub run {
    select_console 'root-console';

    my $file_raw      = "hello.txt";
    my $dgst_alg      = "sha256";
    my $file_dgt      = $file_raw . ".$dgst_alg";
    my $file_sig      = $file_dgt . ".sig";
    my @dsa_key_sizes = (1024, 2048, 3072);

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

        # Sign message digest with private key
        assert_script_run "openssl dgst -dss1 -sign $dsa_prikey $file_dgt > $file_sig";

        # Verify signature with public key
        validate_script_output "openssl dgst -dss1 -verify $dsa_pubkey -signature $file_sig $file_dgt", sub { m/Verified OK/ };

        # Clean up temp files
        script_run "rm -f $file_dgt $file_sig dsaparam.pem";
    }

    script_run 'cd - && rm -rf fips-test';
}

1;
