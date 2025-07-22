# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: Ensure using NetworkManager as system network manager
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'y2_module_guitest';
use y2_base;
use testapi;
use utils;

sub run {
    my $self = shift;

    select_console 'root-console';
    my $nm_is_active = (script_run("readlink /etc/systemd/system/network.service | grep NetworkManager") == 0);
    select_console 'x11';

    # return if NetworkManager is already configured as system network manager
    return if ($nm_is_active);

    $self->configure_system;
}

sub configure_system {
    # we have to change the networkmanager form wicked to NetworkManager
    y2_module_guitest::launch_yast2_module_x11('lan');
    assert_screen 'yast2_control-center_network-opened';

    # switch to 'Global options'
    assert_and_click 'yast2_network-global_options-click';
    send_key('alt-f10', wait_screen_change => 10);
    # open the networkmanager dropdown and select 'NetworkManager'
    assert_and_click 'yast2_network-nm_selection-click';
    assert_and_click 'yast2_network-network_manager-click';
    assert_screen 'yast2_network-network_manager-selected';
    # now apply the settings
    assert_and_click 'yast2_network-apply_settings-click';
    assert_and_click 'yast2_network-applet_warning-click';
    check_screen 'yast2_network-is_applying';

    assert_screen([qw(generic-desktop yast2_network-error_dialog)]);
    if (match_has_tag 'yast2_network-error_dialog') {
        record_soft_failure 'boo#1049097';
        assert_and_click 'yast2_network-error_dialog';
    }
}

1;
