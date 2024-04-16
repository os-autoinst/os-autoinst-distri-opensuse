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

    my $usb_net_devs = script_output('readlink /sys/class/net/* | grep usb', proceed_on_failure => 1);
    die "no USB network interfaces found" unless $usb_net_devs ne "";

    my $interface = script_output "basename $usb_net_devs | head -n1";

    assert_script_run "echo \"BOOTPROTO='dhcp'\" > /etc/sysconfig/network/ifcfg-$interface";
    assert_script_run "echo \"STARTMODE='auto'\" >> /etc/sysconfig/network/ifcfg-$interface";

    assert_script_run("ifup $interface -o debug", 60);

    sleep 30;
    my $inet = script_output("ip addr show dev $interface |  awk \'/inet / {split(\$0,a); print a[2]}\'", proceed_on_failure => 1);
    die "no IP address configured" unless $inet ne "";

    record_info("IP address(es)", "$inet");

    my $neigh = script_output("ip neigh show dev $interface");
    my $peer_count = 0;

    while ($neigh =~ m/^(\S+)/mg) {
        return unless script_run "ping -I $interface -c 4 $1";
        $peer_count++;
    }

    record_info("Ping failed", "None of $peer_count peers responded to ping", result => 'fail');
}

sub test_flags {
    return {fatal => 0};
}

1;
