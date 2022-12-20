# SUSE's openQA tests
# openssl FIPS test
#
# Copyright 2022 SUSE LLC
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

    # Separate the different openssl command usage between SLE12 and SLE15
    if (is_sle('<15')) {
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
    } else {
        eval {
            validate_script_output
"echo -n 'Invalid Hash: '; openssl list -digest-algorithms | sed -e '/SHA1/d' -e '/SHA224/d' -e '/SHA256/d' -e '/SHA384/d' -e '/SHA512/d' -e '/DSA/d' -e '/SHA3-224/d' -e '/SHA3-256/d' -e '/SHA3-384/d' -e '/SHA3-512/d' -e '/SHAKE128/d' -e '/SHAKE256/d' | wc -l",
              sub { m/^Invalid Hash: 0$/ };

            validate_script_output
"echo -n 'Invalid Pubkey: '; openssl list -public-key-algorithms | grep '^Name' | sed -e '/RSA/d' -e '/rsa/d' -e '/DSA/d' -e '/dsa/d' -e '/EC/d' -e '/DH/d' -e '/HMAC/d' -e '/CMAC/d' | wc -l",
              sub { m/^Invalid Pubkey: 0$/ };
        }
    }
}

sub test_flags {
    return {fatal => 0};
}

1;
