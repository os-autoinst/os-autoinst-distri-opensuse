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
# Summary: This test adds some devices to our VMs
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use xen;
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

    # guests where we need to apply workaround for bsc#1172356
    my @bsc1172356_guests;

    foreach my $guest (keys %xen::guests) {
        unless ($guest =~ m/hvm/i) {
            record_info "$guest", "VM $guest will get some new devices";

            select_guest($guest);
            detect_login_screen();

            mouse_set(0, 0);
            assert_and_click 'virt-manager_details';
            send_key 'alt-f10';
            assert_and_click 'virt-manager_add-hardware';
            mouse_set(0, 0);
            assert_and_click 'virt-manager_add-storage';
            if (check_screen 'virt-manager_add-storage-ide') {
                assert_and_click 'virt-manager_add-storage-ide';
                assert_and_click 'virt-manager_add-storage-select-xen';
            }
            assert_screen 'virt-manager_add-storage-xen';
            assert_and_click 'virt-manager_add-hardware-finish';

            assert_and_click 'virt-manager_add-hardware';
            mouse_set(0, 0);
            assert_and_click 'virt-manager_add-network';
            send_key 'tab';
            send_key 'tab';
            send_key 'tab';
            type_string '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
            assert_and_click 'virt-manager_add-hardware-finish';
            # Workaround for bsc#1172356
            if (check_screen('virt-manager_add_network_bsc1172356', timeout => 20)) {
                record_soft_failure('bsc#1172356', 'Virt-manager cannot add NIC');
                assert_and_click 'virt-manager_add_network_bsc1172356';
                push(@bsc1172356_guests, "$guest");
            } else {
                assert_and_click 'virt-manager_disk2';
                assert_screen 'virt-manager_disk2_name';
                assert_and_click 'virt-manager_nic2';
            }

            assert_and_click 'virt-manager_graphical-console';

            detect_login_screen();
            close_guest();
        }
    }

    wait_screen_change { send_key 'ctrl-q'; };

    # Note: hotplugging in virsh is tested in hotplugging.pm
    # We still add the NIC here, so virtmanager_rm_devices finds it
    if (@bsc1172356_guests) {
        foreach my $guest (@bsc1172356_guests) {
            my $mac = '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
            script_run("virsh attach-interface --domain $guest --type bridge --source br0 --live --mac $mac");
        }
        save_screenshot;
    }
}

1;

