# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB NIC connected to system
# Maintainer: LSG QE Kernel <kerneli-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Logging 'export_logs_basic';

sub run {
    my ($self) = @_;

    select_serial_terminal;

    zypper_call('in -t package ethtool');

    my $interface = script_output 'basename $(readlink /sys/class/net/* | grep usb )';

    assert_script_run "echo \"BOOTPROTO='dhcp'\" > /etc/sysconfig/network/ifcfg-$interface";
    assert_script_run "echo \"STARTMODE='auto'\" >> /etc/sysconfig/network/ifcfg-$interface";

    assert_script_run "ifup $interface";

    # wait until interface is up
    my $timeout = 20;
    ($timeout-- && sleep 5) while (script_run "ip -4 addr show $interface | grep inet" && $timeout);

    my $ping_peer = script_output "ip route show dev $interface | cut -d ' ' -f 7";
    assert_script_run "ping -I $interface -c 4 $ping_peer";
    assert_script_run "ifdown $interface";
}

sub test_flags {
    return {fatal => 0};
}

1;
