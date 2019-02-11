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
# Summary: This test removed aditional HV from our VMs
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "x11test";
use xen;
use strict;
use warnings;
use testapi;
use utils;
use virtmanager qw(detect_login_screen select_guest);

sub run {
    my ($self) = @_;
    select_console 'x11';

    x11_start_program 'virt-manager';
    assert_screen "virt-manager_connected";

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "VM $guest will loose it's aditional HV";

        select_guest($guest);
        detect_login_screen();

        assert_and_click 'virt-manager_details';

        assert_and_click 'virt-manager_disk2';
        assert_screen 'virt-manager_disk2_name';
        assert_and_click 'virt-manager_remove';
        if (check_screen 'virt-manager_remove_disk2', 2) {
            assert_and_dclick 'virt-manager_remove_disk2_yes';
        }
        wait_still_screen 3;

        assert_and_click 'virt-manager_nic2';
        assert_and_click 'virt-manager_remove';
        if (check_screen 'virt-manager_remove_nic2', 2) {
            assert_and_dclick 'virt-manager_remove_nic2_yes';
        }
        wait_still_screen 2;

        assert_and_click 'virt-manager_graphical-console';

        detect_login_screen();
        assert_and_click 'virt-manager_file';
        assert_and_click 'virt-manager_close';
    }

    wait_screen_change { send_key 'alt-f4'; };
}

1;

