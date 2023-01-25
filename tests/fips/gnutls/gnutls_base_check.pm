# Copyright 2020-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: gnutls / libnettle
# Summary: SLES15SP2 and SLES15SP4 FIPS certification need to certify gnutls and libnettle
#          In this case, will do some base check for gnutls
#
# Maintainer: QE Security <none@suse.de>, Ben Chou <bchou@suse.com>
# Tags: poo#63223, poo#102770, tc#1744099

use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils 'zypper_call';
use version_utils qw(is_tumbleweed is_leap is_sle);

sub run {
    select_serial_terminal;

    # Install the gnutls / libnettle packages (pulled as dependency)
    zypper_call('in gnutls');

    my $current_ver = script_output("rpm -q --qf '%{version}\n' gnutls");
    record_info('gnutls version', "Version of Current gnutls package: $current_ver");

    # gnutls attempt to update to 3.7.2+ in SLE15 SP4 base on the feature
    # SLE-19765: Update libnettle and gnutls to new major versions
    # starting with gnu nettle 3.6+: Support for ED448 signature
    unless (is_sle('<15-SP4') || is_leap('<15.4')) {
        assert_script_run "gnutls-cli --list | tee -a /dev/$serialdev | grep -w SIGN-EdDSA-Ed448";
    }

    # Check the library is in FIPS kernel mode, and skip checking this in FIPS ENV mode
    # Since ENV mode is not pulled out/installed the fips library
    if (!get_var("FIPS_ENV_MODE")) {
        validate_script_output 'gnutls-cli --fips140-mode 2>&1', sub {
            m/
                library\sis\sin\sFIPS140-[2-3]\smode.*/sx
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
