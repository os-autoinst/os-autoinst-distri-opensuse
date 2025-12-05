# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package Kernel::usb;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;

our @EXPORT = qw(
  list_usb_devices
  check_usb_devices
);

=head1 SYNOPSIS

Utils for working with USB devices.

=cut

=head2 list_usb_devices

 list_usb_devices();

Returns an array of hashes with the following information about all detected
USB devices:
- C<bus>: System bus number
- C<device>: Device number on the bus
- C<vendor>: Vendor ID
- C<product>: Vendor-specific product ID
- C<name>: Human-readable description returned by the device

=cut

sub list_usb_devices {
    my @errors;
    my @ret;
    my $lsusb = script_output('lsusb');

    for my $line (split /\n/, $lsusb) {
        if ($line !~ m/^Bus (\d+) Device (\d+): ID ([0-9a-fA-F]+):([0-9a-fA-F]+) (.*)$/) {
            push @errors, $line;
            next;
        }

        push @ret, {
            bus => $1,
            device => $2,
            vendor => $3,
            product => $4,
            name => $5
        };
    }

    if (@errors) {
        record_info('lsusb error', "Unrecognized data in lsusb output:\n" . join("\n", @errors), result => 'fail');
    }

    return \@ret;
}

=head2

 check_usb_devices();

Check that all devices listed in C<REQUIRED_USB_DEVICES> job setting are
connected to the test machine. The variable must contain a comma-separated
list of vendor:product IDs.

=cut

sub check_usb_devices {
    my %devmap;
    my @missing;
    my $checklist = get_var('REQUIRED_USB_DEVICES');
    my $devlist = list_usb_devices;

    return unless $checklist;

    for my $item (@$devlist) {
        $devmap{"$$item{vendor}:$$item{product}"} = $item;
    }

    for my $dev (split /,/, $checklist) {
        push @missing, $dev unless defined($devmap{$dev});
    }

    record_info('Missing USB devices',
        "The following USB devices are missing:\n" . join("\n", @missing),
        result => 'fail') if @missing;
    return wantarray ? @missing : (scalar @missing);
}

1;
