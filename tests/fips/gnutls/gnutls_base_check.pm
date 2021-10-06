# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: gnutls openssl
# Summary: SLES15SP2 FIPS certification, we need to certify gnutls and libnettle
#          In this case, will do some base check for gnutls
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#63223, tc#1744099

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils 'zypper_call';
use version_utils qw(is_tumbleweed);

sub run {
    select_console 'root-console';

    # Install the gnutls and openssl apackages
    zypper_call 'in gnutls openssl';

    # Check the library is in FIPS kernel mode, and skip checking this in FIPS ENV mode
    # Since ENV mode is not pulled out/installed the fips library
    if (!get_var("FIPS_ENV_MODE")) {
        validate_script_output 'gnutls-cli --fips140-mode 2>&1', sub {
            m/
                library\sis\sin\sFIPS140-2\smode.*/sx
        };
    }

    # Lists all ciphers, check the certificate types and double confirm TLS1.3,DTLS1.2 and SSL3.0
    assert_script_run 'gnutls-cli -l | grep "Certificate types" | grep "CTYPE-X.509"';
    my $re_proto = is_tumbleweed ? 'grep -e VERS-TLS1.2 -e VERS-TLS1.3 -e VERS-DTLS1.2' : 'grep -e VERS-SSL3.0 -e VERS-TLS1.3 -e VERS-DTLS1.2';
    assert_script_run "gnutls-cli -l | grep Protocols | $re_proto";

    # Check google's imap server and verify basic function
    validate_script_output 'echo | gnutls-cli -d 1 imap.gmail.com -p 993', sub {
        m/
            Certificate\stype:\sX\.509.*
            Status:\sThe\scertificate\sis\strusted.*
            Description:\s\(TLS1\.3.*\).*
            Handshake\swas\scompleted.*/sx
    };
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
