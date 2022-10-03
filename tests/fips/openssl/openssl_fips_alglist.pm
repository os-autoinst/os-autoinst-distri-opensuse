# SUSE's openQA tests
# openssl FIPS test
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: openssl
# Summary: openssl should only list FIPS approved cryptographic functions
#          while system is working in FIPS mode
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44831, poo#65375, poo#101932, poo#111818

use base "consoletest";
use testapi;
use strict;
use warnings;
use utils 'zypper_call';
use version_utils qw(is_sle);

sub run {
    select_console 'root-console';

    zypper_call('in openssl');
    zypper_call('info openssl');
    my $current_ver = script_output("rpm -q --qf '%{version}\n' openssl");

    # openssl attempt to update to 1.1.1+ in SLE15 SP4 base on the feature
    # SLE-19640: Update openssl 1.1.1 to current stable release
    if (!is_sle('<15-sp4') && ($current_ver ge 1.1.1)) {
        record_info('openssl version', "Version of Current openssl package: $current_ver");
    }
    else {
        record_soft_failure('jsc#SLE-19640: openssl version is outdated and need to be updated over 1.1.1+ for SLE15-SP4');
    }

    # Seperate the diffrent openssl command usage between SLE12 and SLE15
    if (is_sle('<15')) {
        # List cipher algorithms in fips mode
        # only AES and DES3 are approved in fips mode
        validate_script_output
          "echo -n 'Invalid Cipher: '; openssl list-cipher-algorithms | sed -e '/AES/d' -e '/aes/d' -e '/DES3/d' -e '/des3/d' -e '/DES-EDE/d' | wc -l",
          sub { m/^Invalid Cipher: 0$/ };

        # List message digest algorithms in fips mode
        # only SHA1 and SHA2 (224, 256, 384, 512) are approved in fips mode
        # Note: DSA is short of DSA-SHA1, so it is also valid item
        validate_script_output
"echo -n 'Invalid Hash: '; openssl list-message-digest-algorithms | sed -e '/SHA1/d' -e '/SHA224/d' -e '/SHA256/d' -e '/SHA384/d' -e '/SHA512/d' -e '/DSA/d' | wc -l",
          sub { m/^Invalid Hash: 0$/ };

        # List public key algorithms in fips mode
        # only RSA, DSA, ECDSA, EC DH, CMAC and HMAC are approved in fips mode
        validate_script_output
"echo -n 'Invalid Pubkey: '; openssl list-public-key-algorithms | grep '^Name' | sed -e '/RSA/d' -e '/rsa/d' -e '/DSA/d' -e '/dsa/d' -e '/EC/d' -e '/DH/d' -e '/HMAC/d' -e '/CMAC/d' | wc -l",
          sub { m/^Invalid Pubkey: 0$/ };
    }

    # openssl-1.1.0 is working in SLE15
    # The openssl command is adjustment
    else {
        # Add 3DES and 3des support
        eval {
            validate_script_output(
"echo -n 'Invalid Cipher: '; openssl list -cipher-algorithms | sed -e '/AES/d' -e '/aes/d' -e '/DES3/d' -e '/des3/d' -e '/DES-EDE/d' -e '/3DES/d' -e '/3des/d' | wc -l",
                sub { m/^Invalid Cipher: 0$/ }); };
        if ($@) {
            # It is not an important function, just record soft failure.
            # POO#111818
            record_soft_failure('bsc#1161276 - It is not important function about openssl list -cipher-algorithms, and marked this as WONTFIX'); }

        validate_script_output
"echo -n 'Invalid Hash: '; openssl list -digest-algorithms | sed -e '/SHA1/d' -e '/SHA224/d' -e '/SHA256/d' -e '/SHA384/d' -e '/SHA512/d' -e '/DSA/d' | wc -l",
          sub { m/^Invalid Hash: 0$/ };

        validate_script_output
"echo -n 'Invalid Pubkey: '; openssl list -public-key-algorithms | grep '^Name' | sed -e '/RSA/d' -e '/rsa/d' -e '/DSA/d' -e '/dsa/d' -e '/EC/d' -e '/DH/d' -e '/HMAC/d' -e '/CMAC/d' | wc -l",
          sub { m/^Invalid Pubkey: 0$/ };
    }

}

sub test_flags {
    return {fatal => 0};
}

1;
