# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: SLES15SP2 FIPS certification, we need to certify gnutls and libnettle
#          In this case, will do some base check for gnutls
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#63223, tc#1744099

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils 'zypper_call';

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
    assert_script_run 'gnutls-cli -l | grep Protocols | grep VERS-SSL3.0 | grep VERS-TLS1.3 | grep VERS-DTLS1.2';

    # Check google's imap server and verify basic function
    validate_script_output 'echo | gnutls-cli -d 1 imap.gmail.com -p 993', sub {
        m/
            Certificate\stype:\sX\.509.*
            Status:\sThe\scertificate\sis\strusted.*
            Description:\s\(TLS1\.3\).*
            Handshake\swas\scompleted.*/sx
    };
}

sub test_flags {
    return {milestone => 1, fatal => 0};
}

1;
