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
# Summary: This test turns all VMs off and then on again
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
        record_info "$guest", "VM $guest will be turned off and then on again";

        select_guest($guest);

        assert_and_click 'virt-manager_view';
        assert_and_click 'virt-manager_resizetovm';

        detect_login_screen();

        assert_and_click 'virt-manager_shutdown';
        if (!check_screen 'virt-manager_notrunning', 30) {
            assert_and_click 'virt-manager_shutdown_menu';
            assert_and_click 'virt-manager_shutdown_item';
            # There migh me 'Are you sure' dialog window
            if (check_screen "virt-manager_shutdown_sure", 2) {
                assert_and_click "virt-manager_shutdown_sure";
            }
        }
        assert_and_click 'virt-manager_poweron', 'left', 90;

        detect_login_screen(120);
        assert_and_click 'virt-manager_file';
        assert_and_click 'virt-manager_close';

    }

    wait_screen_change { send_key 'alt-f4'; };
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

