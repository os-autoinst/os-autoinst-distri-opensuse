# openssl fips test
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: FIPS : openssl should only list FIPS approved cryptographic functions
#                 while system is working in fips mode
#
# Original Author: Qingming Su <qingming.su@suse.com>
# Maintainer: Ben Chou <bchou@suse.com>
# Tags: poo#44831

use base "consoletest";
use testapi;
use strict;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';

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
        validate_script_output
"echo -n 'Invalid Cipher: '; openssl list -cipher-algorithms | sed -e '/AES/d' -e '/aes/d' -e '/DES3/d' -e '/des3/d' -e '/DES-EDE/d' -e '/3DES/d' -e '/3des/d' | wc -l",
          sub { m/^Invalid Cipher: 0$/ };

        validate_script_output
"echo -n 'Invalid Hash: '; openssl list -digest-algorithms | sed -e '/SHA1/d' -e '/SHA224/d' -e '/SHA256/d' -e '/SHA384/d' -e '/SHA512/d' -e '/DSA/d' | wc -l",
          sub { m/^Invalid Hash: 0$/ };

        validate_script_output
"echo -n 'Invalid Pubkey: '; openssl list -public-key-algorithms | grep '^Name' | sed -e '/RSA/d' -e '/rsa/d' -e '/DSA/d' -e '/dsa/d' -e '/EC/d' -e '/DH/d' -e '/HMAC/d' -e '/CMAC/d' | wc -l",
          sub { m/^Invalid Pubkey: 0$/ };
    }

}

1;
