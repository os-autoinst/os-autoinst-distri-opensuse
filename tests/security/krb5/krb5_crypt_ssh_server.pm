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
# Summary: Test ssh with krb5 authentication - server
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Ticket: poo#51560, poo#51566

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

    assert_script_run "kadmin -p $adm -w $pass_a -q 'addprinc -pw $pass_t $tst'";
    assert_script_run "useradd -m $tst";

    # Config sshd
    foreach my $i ('GSSAPIAuthentication', 'GSSAPICleanupCredentials') {
        assert_script_run "sed -i 's/^#$i .*\$/$i yes/' /etc/ssh/sshd_config";
    }
    systemctl("restart sshd");

    mutex_create('CONFIG_READY_SSH_SERVER');

    # Waiting for the finishd of krb5 client
    my $children = get_children();
    mutex_wait('TEST_DONE_SSH_CLIENT', (keys %$children)[0]);
    mutex_create('TEST_DONE_SSH_SERVER');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
