# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: virt-manager
# Summary: This test turns just check all VMs
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "virt_feature_test_base";
#use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use virtmanager;

sub run_test {
    select_console 'root-console';
    my @guests = @{get_var_array("TEST_GUESTS")};
    zypper_call '-t in virt-manager', exitcode => [0, 4, 102, 103, 106];

    #x11_start_program 'virt-manager';
    enter_cmd "virt-manager";

    establish_connection();

    foreach my $guest (@guests) {
        record_info "$guest", "VM $guest will be turned off and then on again";

        select_guest($guest);

        detect_login_screen();

        close_guest();
    }

    wait_screen_change { send_key 'ctrl-q'; };
}

1;

