# Copyright (C) 2019 SUSE LLC
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
# Summary: This test fetch SSH keys of all guests and authorize the client one
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Establishing SSH connection to $guest";

        # Establish the SSH connection and transfer client key
        script_retry "nmap $guest -PN -p ssh | grep open", delay => 15, retry => 12;
        assert_script_run "ssh-keyscan $guest >> ~/.ssh/known_hosts";
        if (script_run("ssh -o PreferredAuthentications=publickey root\@$guest hostname -f") != 0) {
            exec_and_insert_password "ssh-copy-id root\@$guest";
        }
        assert_script_run "ssh root\@$guest rm /etc/cron.d/qam_cron; hostname";
    }
    assert_script_run "echo 'PreferredAuthentications publickey' >> ~/.ssh/config";
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

