# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: YaST2 Firewall UI test checks various configurations and settings of firewall
# Make sure yast2 firewall can opened properly. Configurations can be changed and written correctly.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;
use network_utils 'iface';
use YaST::Module;
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;
    my $iface = iface();
    my %setting = (device => $iface, zone => 'public');

    select_console 'x11', await_console => 0;
    YaST::Module::open(module => 'firewall', ui => 'qt');
    $testapi::distri->get_firewall()->select_interfaces_page();
    save_screenshot;
    $testapi::distri->get_firewall()->set_interface_zone($setting{device}, $setting{zone});
    save_screenshot;
    $testapi::distri->get_firewall()->accept_change();
    assert_screen 'generic-desktop';
    select_serial_terminal();
    validate_script_output("firewall-cmd --list-interfaces --zone=$setting{zone}", sub { m/$setting{device}/ }, proceed_on_failure => 1);
}

1;
