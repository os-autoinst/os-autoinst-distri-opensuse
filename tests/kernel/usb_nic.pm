# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: usb_nic
# Summary: Simple smoke test for testing USB NIC connected to system
# Maintainer: LSG QE Kernel <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use network_utils 'is_wicked_used';
use Kernel::usb;

sub run {
    my ($self) = @_;

    select_serial_terminal;
    check_usb_devices;

    my $usb_net_devs = script_output('readlink /sys/class/net/* | grep usb', proceed_on_failure => 1);
    die "no USB network interfaces found" unless $usb_net_devs ne "";

    my $interface = script_output "basename $usb_net_devs | head -n1";
    record_info("USB Interface", $interface);

    if (is_wicked_used) {
        assert_script_run "echo \"BOOTPROTO='dhcp'\" > /etc/sysconfig/network/ifcfg-$interface";
        assert_script_run "echo \"STARTMODE='auto'\" >> /etc/sysconfig/network/ifcfg-$interface";

        assert_script_run("ifup $interface -o debug");
    } else {
        assert_script_run("nmcli device set $interface managed yes");
        assert_script_run("nmcli connection add type ethernet ifname $interface con-name usbnic-$interface autoconnect yes ipv4.method auto");
        assert_script_run("nmcli connection up usbnic-$interface");
    }

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

=head1 Description

Smoke test for a USB network adapter connected to the SUT. The test looks for
a network interface backed by a USB device and configures it for DHCP, using
wicked or NetworkManager depending on which one is in use. It then checks that
the interface got an IP address and pings the neighbours it has discovered.
The test passes as soon as one neighbour responds.

The machine the test runs on must have a USB NIC plugged in and connected to a
network with a DHCP server.

=head1 Configuration

=head2 REQUIRED_USB_DEVICES

Optional comma-separated list of C<vendor:product> USB IDs, for example
C<0bda:8153>, that must be connected to the SUT. Missing devices are reported
as a failure, but the test keeps going.

=cut
