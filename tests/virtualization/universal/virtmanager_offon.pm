# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: virt-manager
# Summary: This test turns all VMs off and then on again
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use testapi;
use utils;
use virtmanager;
use virt_autotest::utils qw(reconnect_console_if_not_good);

sub run_test {
    my ($self) = @_;

    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "VM $guest will be turned off and then on again";

        select_guest($guest);

        assert_and_click 'virt-manager_view';
        assert_and_click 'virt-manager_resizetovm';

        detect_login_screen();
        powercycle();
        detect_login_screen(300);
        close_guest();
    }

    wait_screen_change { send_key 'ctrl-q'; };

    # Wait a while untill the ssh console fully reacts after closing the X window of virt-manager
    sleep 5;
    # Reconnect if the text console does not respond well after long time no use
    reconnect_console_if_not_good;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

