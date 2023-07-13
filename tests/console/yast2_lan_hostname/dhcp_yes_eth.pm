# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: Verify that correct value is stored in network config when
# setting hostname via DHCP to 'yes: <ethernet network interface>' in
# YaST2 lan module (https://bugzilla.suse.com/show_bug.cgi?id=984890)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent 'yast2_lan_hostname_base';
use strict;
use warnings;
use testapi;
use scheduler qw(get_test_suite_data);
use YaST::Module;

sub run {
    select_console 'root-console';
    my $network_interface = script_output('ls /sys/class/net | grep ^e');
    my $test_data = get_test_suite_data();

    YaST::Module::run_actions {
        my $network_settings = $testapi::distri->get_network_settings();
        $network_settings->confirm_warning() if $test_data->{yast2_lan_hostname}->{confirm_warning};
        $network_settings->set_hostname_via_dhcp({dhcp_option => "yes: $network_interface"});
        $network_settings->save_changes();
    } module => 'lan', ui => $test_data->{yast2_lan_hostname}->{ui};

    assert_script_run 'iface=`ip -o addr show scope global | head -n1 | cut -d" " -f2`';
    assert_script_run 'grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/ifcfg-$iface|grep yes';
    assert_script_run 'grep DHCLIENT_SET_HOSTNAME /etc/sysconfig/network/dhcp|grep no';
}

1;
