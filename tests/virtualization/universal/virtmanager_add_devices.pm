# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: virt-manager
# Summary: This test adds some devices to our VMs
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use virtmanager;

sub run_test {
    my ($self) = @_;
    my @guests = keys %virt_autotest::common::guests;
    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    foreach my $guest (@guests) {
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
                send_key 'tab' if is_sle('15-sp2+');    # Details / XML panel
                send_key 'tab' if is_sle('15-sp3+');    # Device name input field
                type_string '00:16:3e:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
                save_screenshot();
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

