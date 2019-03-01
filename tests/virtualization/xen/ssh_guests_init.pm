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
    select_console 'root-console';
    opensusebasetest::select_serial_terminal();
    my $hypervisor = get_required_var('HYPERVISOR');

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Establishing SSH connection to $guest";

        # Fill the current pairs of hostname & address into /etc/hosts file
        assert_script_run "ssh root\@$hypervisor 'sed -i \"/$guest/d\" /etc/hosts'";
        assert_script_run qq(ssh root\@$hypervisor 'echo `virsh net-dhcp-leases default | awk "/$guest/ {print substr(\\\\\$5, 1, length(\\\\\$5)-3)}"` $guest >> /etc/hosts');
        assert_script_run "ssh root\@$hypervisor 'cat /etc/hosts | grep $guest'";

        # Establish the SSH connection and transfer client key
        assert_script_run "ssh root\@$hypervisor 'ping -c3 -W1 $guest'";
        assert_script_run "ssh root\@$hypervisor 'ssh-keyscan $guest' >> ~/.ssh/known_hosts";
        if (script_run("ssh -o PreferredAuthentications=publickey root\@$guest hostname -f") != 0) {
            exec_and_insert_password "ssh-copy-id -f root\@$guest";
        }
        assert_script_run "ssh root\@$guest hostname -f";
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

