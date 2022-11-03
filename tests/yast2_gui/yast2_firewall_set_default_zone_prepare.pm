# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: This module should schedule before yast2_firewall_set_default_zone.pm on SLES productor since
# TW set default zone with iface together but sle not, so we need update iface's zone to trusted zone firstly
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
    my %settings = (device => $iface, zone => 'trusted');

    select_console 'x11', await_console => 0;
    YaST::Module::open(module => 'firewall', ui => 'qt');
    $testapi::distri->get_firewall()->select_interfaces_page();
    save_screenshot;
    $testapi::distri->get_firewall()->set_interface_zone($settings{device}, $settings{zone});
    save_screenshot;
    $testapi::distri->get_firewall()->accept_change();
    assert_screen 'generic-desktop';
    $self->select_serial_terminal();
    validate_script_output("firewall-cmd --list-interfaces --zone=$settings{zone}", sub { m/$settings{device}/ }, proceed_on_failure => 0);
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'root-console';
    $self->save_upload_y2logs;
}

1;
