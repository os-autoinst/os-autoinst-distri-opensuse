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
#          In this case, will test connecting the GnuTLS server from client
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#63223, tc#1744099

use base "consoletest";
use testapi;
use strict;
use warnings;

sub run {
    select_console "root-console";

    # Switch to the original folder contains the key/password files
    my $test_dir = "gnutls";
    assert_script_run "cd $test_dir";
    my $user   = "psk_identity";
    my $passwd = "psk-passwd.txt";
    my $psk    = script_output "cat $passwd | awk -F : '{print \$2}'";

    # Connect to the server and make sure the handshake
    validate_script_output "echo |gnutls-cli -p 5556 localhost --pskusername $user --pskkey $psk --priority NORMAL:-KX-ALL:+ECDHE-PSK:+DHE-PSK:+PSK",
      sub { m/Handshake was completed/ };
}

1;
