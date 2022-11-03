# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: YaST2 Firewall UI test checks verious configurations and settings of firewall
# Make sure yast2 firewall can opened properly. Configurations can be changed and written correctly.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "y2_module_guitest";
use strict;
use warnings;
use testapi;
use utils;
use network_utils 'iface';
use YaST::Module;

sub run {
    my $self = shift;
    my $iface = iface();

    $self->select_serial_terminal();
    validate_script_output("firewall-cmd --get-default-zone", sub { m/public/ }, proceed_on_failure => 1);
    select_console 'x11', await_console => 0;
    YaST::Module::open(module => 'firewall', ui => 'qt');
    $testapi::distri->get_firewall()->select_interfaces_page();
    save_screenshot;
    $testapi::distri->get_firewall()->select_zones_page();
    save_screenshot;
    $testapi::distri->get_firewall()->set_default_zone("trusted");
    save_screenshot;
    $testapi::distri->get_firewall()->accept_change();
    assert_screen 'generic-desktop';
    $self->select_serial_terminal();
    validate_script_output("firewall-cmd --list-interfaces --zone=trusted", sub { m/$iface/ }, proceed_on_failure => 1);
    validate_script_output("firewall-cmd --get-default-zone", sub { m/trusted/ }, proceed_on_failure => 1);

}

1;
