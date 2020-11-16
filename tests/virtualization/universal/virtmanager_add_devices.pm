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
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use virtmanager;

sub run {
    my ($self) = @_;

    #x11_start_program 'virt-manager';
    type_string "virt-manager\n";

    establish_connection();

    foreach my $guest (keys %virt_autotest::common::guests) {
        unless ($guest =~ m/hvm/i) {
            record_info "$guest", "VM $guest will get some new devices";
            my $attachFail = 0;    # Indicating if we are having problems attaching devices

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
            # Live-attaching sometimes failes because of bsc#1172356
            # the test should not die because of this
            if (check_screen('virt-manager_add-hardware-noliveattach', timeout => 20)) {
                record_soft_failure("bsc#1172356 Live-attaching disk failed on $guest");
                assert_and_click 'virt-manager_add-hardware-noliveattach';
                $attachFail = 1;
            } else {
                assert_and_click 'virt-manager_add-hardware';
            }
            mouse_set(0, 0);
            if ($attachFail == 0) {
                assert_and_click 'virt-manager_add-network';
                send_key 'tab';
                send_key 'tab';
                send_key 'tab';
                send_key 'tab' if is_sle('15-sp2+');
                type_string '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
                assert_and_click 'virt-manager_add-hardware-finish';
                # Live-attaching sometimes failes because of bsc#1172356
                # the test should not die because of this
                if (check_screen('virt-manager_add_network_bsc1172356', timeout => 20)) {
                    record_soft_failure("bsc#1172356 Live-attaching NIC failed on $guest");
                    assert_and_click 'virt-manager_add_network_bsc1172356';
                } else {
                    assert_and_click 'virt-manager_disk2';
                    assert_screen 'virt-manager_disk2_name';
                    assert_and_click 'virt-manager_nic2';
                }
            }

            assert_and_click 'virt-manager_graphical-console';

            detect_login_screen() if (!check_screen('virt-manager_viewer_disconnected', 5));
            close_guest();
        }
    }

    wait_screen_change { send_key 'ctrl-q'; };
}

1;

