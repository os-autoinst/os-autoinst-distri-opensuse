# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configures yast2 by its GUI to use NetworkManager as system network manager
# Maintainer: Nick Singer <nsinger@suse.de>
# Tags: poo#20306

use base 'x11test';
use y2x11test 'launch_yast2_module_x11';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    select_console 'x11';
    $self->configure_system;
}

sub configure_system {
    my $self = shift;

    # we have to change the networkmanager form wicked to NetworkManager
    y2x11test::launch_yast2_module_x11 module => 'lan';
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

    if (check_screen 'yast2_network-error_dialog') {
        record_soft_failure 'boo#1049097';
        assert_and_click 'yast2_network-error_dialog';
        # TODO: collect yast2 logs
    }
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    # TODO: collect yast2 logs
    $self->SUPER::post_fail_hook;
}

1;
