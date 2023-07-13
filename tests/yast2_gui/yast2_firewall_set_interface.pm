# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: YaST2 Firewall UI test checks verious configurations and settings of firewall
# Make sure yast2 firewall can opened properly. Configurations can be changed and written correctly.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

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
    select_console 'root-console';
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
    select_console 'root-console';
    systemctl 'restart firewalld', timeout => 200 if (script_run(("grep 'FlushAllOnReload.*no' /etc/firewalld/firewalld.conf") == 0));
    validate_script_output("firewall-cmd --list-interfaces --zone=$setting{zone}", sub { m/$setting{device}/ }, proceed_on_failure => 1);
    select_console 'x11', await_console => 0;
}

1;
