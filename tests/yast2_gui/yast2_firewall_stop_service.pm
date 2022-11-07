# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: YaST2 Firewall UI test checks verious configurations and settings of firewall
# Make sure yast2 firewall can stop properly. Configurations can be changed and written correctly.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;
use YaST::Module;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;

    select_console 'x11', await_console => 0;
    YaST::Module::open(module => 'firewall', ui => 'qt');

    wait_screen_change(sub { $testapi::distri->get_firewall()->stop_firewall() } );
    save_screenshot;
    $testapi::distri->get_firewall()->accept_change();
    assert_screen 'generic-desktop';

    select_serial_terminal();
    validate_script_output("firewall-cmd --state", sub { m/91mnot running/ }, proceed_on_failure => 1);
}

1;
