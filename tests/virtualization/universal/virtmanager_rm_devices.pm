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
# Package: virt-manager
# Summary: This test removed aditional HV from our VMs
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use virtmanager;

sub run {
    my ($self) = @_;

    #x11_start_program 'virt-manager';
    type_string "virt-manager\n";

    establish_connection();

    foreach my $guest (keys %virt_autotest::common::guests) {
        unless ($guest =~ m/hvm/i) {
            record_info "$guest", "VM $guest will loose it's aditional HV";

            select_guest($guest);
            detect_login_screen();

            mouse_set(0, 0);
            assert_and_click 'virt-manager_details';

            # Workaround for bsc#1172356
            if (check_screen('virt-manager_disk2', timeout => 20)) {
                assert_and_click 'virt-manager_disk2';
                assert_screen 'virt-manager_disk2_name';
                assert_and_click 'virt-manager_remove';
                if (check_screen 'virt-manager_remove_disk2', 5) {
                    assert_and_dclick 'virt-manager_remove_disk2_yes';
                }
                wait_still_screen 3;
            } else {
                record_soft_failure("Additional disk not found. Please check hotplugging for bsc#1175218");
            }

            # Check if additional NIC is present
            if (check_screen('virt-manager_nic2', timeout => 20)) {
                assert_and_click 'virt-manager_nic2';
                assert_and_click 'virt-manager_remove';
                if (check_screen 'virt-manager_remove_nic2', 5) {
                    assert_and_dclick 'virt-manager_remove_nic2_yes';
                }
                wait_still_screen 2;
            } else {
                record_soft_failure("Additional NIC not found. Please check hotplugging for bsc#1175218");
            }

            mouse_set(0, 0);
            assert_and_click 'virt-manager_graphical-console';

            detect_login_screen() if (!check_screen('virt-manager_viewer_disconnected', 5));
            close_guest();
        }
    }

    wait_screen_change { send_key 'ctrl-q'; };
}

1;

