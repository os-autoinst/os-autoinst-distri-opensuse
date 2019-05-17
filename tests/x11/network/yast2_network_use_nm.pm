# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Ensure using NetworkManager as system network manager
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use y2_module_guitest 'launch_yast2_module_x11';
use y2_installbase;
use strict;
use warnings;
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
    y2_module_guitest::launch_yast2_module_x11 module => 'lan';
    assert_screen 'yast2_control-center_network-opened';

    # switch to 'Global options'
    assert_and_click 'yast2_network-global_options-click';
    # open the networkmanager dropdown and select 'NetworkManager'
    assert_and_click 'yast2_network-nm_selection-click';
    assert_and_click 'yast2_network-network_manager-click';
    assert_screen 'yast2_network-network_manager-selected';
    # now apply the settings
    assert_and_click 'yast2_network-apply_settings-click';
    assert_and_click 'yast2_network-applet_warning-click';
    assert_screen 'yast2_network-is_applying';

    assert_screen([qw(generic-desktop yast2_network-error_dialog)]);
    if (match_has_tag 'yast2_network-error_dialog') {
        record_soft_failure 'boo#1049097';
        assert_and_click 'yast2_network-error_dialog';
    }
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    y2_installbase::save_upload_y2logs($self);
    $self->SUPER::post_fail_hook;
}

1;
