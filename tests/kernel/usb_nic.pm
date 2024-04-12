# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB NIC connected to system
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $interface = script_output 'basename $(readlink /sys/class/net/* | grep usb )';

    assert_script_run "echo \"BOOTPROTO='dhcp'\" > /etc/sysconfig/network/ifcfg-$interface";
    assert_script_run "echo \"STARTMODE='auto'\" >> /etc/sysconfig/network/ifcfg-$interface";

    assert_script_run("ifup $interface -o debug", 60);

    my $route = script_output "ip route show default";
    my @ping_peer = $route =~ /default via (\S+)/;
    assert_script_run "ping -I $interface -c 4 @ping_peer";
}

sub test_flags {
    return {fatal => 0};
}

1;
