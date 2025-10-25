# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: virt-manager
# Summary: This test turns just check all VMs
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "virt_feature_test_base";
use virt_autotest::common;
use testapi;
use utils;
use virtmanager;

sub run_test {
    # For bare-metal/IPMI backends, we need to use 'root-ssh' which has gui=1 for X11 forwarding
    # For other backends, 'root-console' works fine
    my $console = get_var('BACKEND', '') =~ /ikvm|ipmi|spvm|pvm_hmc/ ? 'root-ssh' : 'root-console';
    
    # Install virt-manager
    select_console $console;
    zypper_call '-t in virt-manager', exitcode => [0, 4, 102, 103, 106];

    # Start virt-manager with SSH X11 forwarding
    start_virtmanager_in_x11();

    foreach my $guest (keys %virt_autotest::common::guests) {
        record_info "$guest", "VM $guest will be turned off and then on again";

        select_guest($guest);

        detect_login_screen();

        close_guest();
    }

    wait_screen_change { send_key 'ctrl-q'; };
}

1;

