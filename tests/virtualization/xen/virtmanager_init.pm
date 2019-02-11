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
# Summary: This test connects to hypervisor and check our VMs
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "x11test";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'x11';
    my $hypervisor = get_required_var('HYPERVISOR');

    x11_start_program 'virt-manager';

    assert_screen 'virt-manager_add-connection';
    if (check_var('REGRESSION', 'xen-client')) {
        send_key 'spc';
        send_key 'down';
        send_key 'down';
        send_key 'spc';
        wait_still_screen 1;    # XEN selected
    }
    send_key 'tab';
    send_key 'spc';
    wait_still_screen 1;        # Connect to remote host ticked
    send_key 'tab';
    send_key 'tab';
    type_string 'root';
    wait_still_screen 1;        # root written
    send_key 'tab';
    type_string "$hypervisor";
    wait_still_screen 1;        # $hypervisor written
    send_key 'tab';
    send_key 'spc';
    wait_still_screen 1;        # autoconnect ticked
    send_key 'ret';
    assert_screen "virt-manager_connected";

    wait_screen_change { send_key 'alt-f4'; };
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

