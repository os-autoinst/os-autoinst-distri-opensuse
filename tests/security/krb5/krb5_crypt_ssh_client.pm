# Copyright © 2019 SUSE LLC
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
# Summary: Test ssh with krb5 authentication - client
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Ticket: poo#51560, poo#51569

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables

sub run {
    select_console 'root-console';

    foreach my $i ('GSSAPIAuthentication', 'GSSAPIDelegateCredentials') {
        assert_script_run "sed -i 's/^.*$i .*\$/$i yes/' /etc/ssh/ssh_config";
    }

    mutex_wait('CONFIG_READY_SSH_SERVER');

    script_run("kinit -p $tst |& tee /dev/$serialdev", 0);
    wait_serial(qr/Password.*$tst/) || die "Matching output failed";
    type_string "$pass_t\n";
    script_output "echo \$?", sub { m/^0$/ };
    validate_script_output "klist", sub {
        m/Default principal.*$tst/;
    };

    # Try connecting to server
    my $ssherr = "ssh login failed";
    script_run("ssh -v -o StrictHostKeyChecking=no $tst\@$dom_server |& tee /dev/$serialdev", 0);
    wait_serial "$tst\@.*~>" || die $ssherr;
    validate_script_output "hostname", sub { m/krb5server/ };

    # Exit the server
    send_key 'ctrl-d';
    validate_script_output "hostname", sub { m/krb5client/ };

    mutex_create('TEST_DONE_SSH_CLIENT');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
