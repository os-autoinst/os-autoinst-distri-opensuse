# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: virt-manager
# Summary: This test turns all VMs off and then on again
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "virt_feature_test_base";
use strict;
use warnings;
use testapi;
use utils;
use virtmanager;

sub run_test {
    my ($self) = @_;
    my @guests = @{get_var_array("TEST_GUESTS")};
    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    foreach my $guest (@guests) {
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
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

