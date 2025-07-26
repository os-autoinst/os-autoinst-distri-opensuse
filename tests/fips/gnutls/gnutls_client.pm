# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: gnutls
# Summary: SLES15SP2 FIPS certification, we need to certify gnutls and libnettle
#          In this case, will test connecting the GnuTLS server from client
# Maintainer: QE Security <none@suse.de>
# Tags: poo#63223, tc#1744099

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Switch to a folder which contains the key/password files
    my $test_dir = "gnutls";
    assert_script_run("cd $test_dir");
    my $user = "psk_identity";
    my $passwd = "psk-passwd.txt";
    my $psk = script_output("awk -F : '{print \$2}' $passwd");

    # Connect to the server
    validate_script_output "echo | gnutls-cli -p 5556 localhost --pskusername $user --pskkey $psk --priority NORMAL:-KX-ALL:+ECDHE-PSK:+DHE-PSK:+PSK",
      sub { m/Handshake was completed/ };
}

1;
