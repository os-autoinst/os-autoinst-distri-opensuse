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
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'x11';
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');

    x11_start_program 'virt-manager', target_match => 'virt-manager';

    assert_screen "virt-manager_add-connection";
    send_key 'spc';
    send_key 'down';
    send_key 'down';
    send_key 'spc';
    save_screenshot;    # XEN selected
    send_key 'tab';
    send_key 'spc';
    save_screenshot;    # Connect to remote host ticked
    send_key 'tab';
    send_key 'tab';
    type_string 'root';
    save_screenshot;    # root written
    send_key 'tab';
    type_string "$hypervisor";
    save_screenshot;    # $hypervisor written
    send_key 'tab';
    send_key 'spc';
    save_screenshot;    # autoconnect ticked
    send_key 'ret';
    assert_screen "virt-manager_connected";

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Going to check $guest console";

        assert_and_dclick "virt-manager_list-$guest";
        if (!check_screen 'virt-manager_login-screen', 30) {
            send_key 'backspace';    # In case screen is off
            assert_and_click 'virt-manager_send-key';
            assert_and_click 'virt-manager_ctrl-alt-f2';
            assert_screen "virt-manager_login-screen";
        }
        wait_screen_change { send_key 'alt-f4'; };
    }

    wait_screen_change { send_key 'alt-f4'; };
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

