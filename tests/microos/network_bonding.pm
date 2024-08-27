# SUSE's openQA tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test network bonding capability and connectivity
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use power_action_utils "power_action";
use utils qw(validate_script_output_retry);
use serial_terminal qw(select_serial_terminal);

sub check_connectivity {
    my ($bond_name) = @_;
    my $ping_host = "conncheck.opensuse.org";
    my $ping_command = "ping -c1 -I $bond_name $ping_host";

    validate_script_output_retry(
        $ping_command,
        sub { m/1 packets transmitted, 1 received, 0% packet loss,/ }
    );
}

sub get_nics {
    my ($bond_name) = @_;
    my @devices;

    foreach my $line (split('\n', script_output('nmcli -g DEVICE conn show'))) {
        next if $line =~ /^\s*$/;

        # Skip the loopback device and the bond interface
        next if $line eq 'lo';
        next if $line eq $bond_name;

        push @devices, $line;
    }

    return @devices;
}

sub delete_existing_connections {
    my $output = script_output('nmcli -g DEVICE,UUID conn show');
    my %seen_uuids;

    foreach my $line (split "\n", $output) {
        next if $line =~ /^\s*$/;

        my ($device, $uuid) = split /:/, $line;
        next if defined $device && $device eq 'lo';
        next if exists $seen_uuids{$uuid};

        $seen_uuids{$uuid} = 1;
        script_run "nmcli con delete uuid '$uuid'";
    }
}

sub create_bond {
    my ($bond_name, $bond_mode, $miimon) = @_;
    assert_script_run "nmcli con add type bond ifname $bond_name con-name $bond_name bond.options \"mode=$bond_mode, miimon=$miimon\"";
    assert_script_run "nmcli connection modify $bond_name connection.autoconnect-slaves 1";
}

sub add_devices_to_bond {
    my ($bond_name, @devices) = @_;
    foreach my $device (@devices) {
        assert_script_run "nmcli con add type ethernet ifname $device master $bond_name";
    }
}

sub test_failover {
    my ($bond_mode, $bond_name, $device, $description, $nics_ref) = @_;
    my @nics_status = map { [$_, $_ eq $device ? 0 : 1] } @$nics_ref;

    record_info("Testing Failover for Mode: $bond_mode", "NIC: $device");

    assert_script_run "ip link set dev $device down";
    script_run 'ip a';

    # Validate bond mode and NIC statuses (the downed NIC should be "down")
    validate_bond_mode_and_slaves($bond_name, $description, \@nics_status);

    check_connectivity $bond_name;

    assert_script_run "ip link set dev $device up";
}

sub validate_bond_mode_and_slaves {
    my ($bond_name, $description, $devices_ref) = @_;

    assert_script_run "cat /proc/net/bonding/$bond_name | grep 'Mode:' | grep '$description'";

    foreach my $device_info (@$devices_ref) {
        my ($device, $status_up) = @$device_info;
        my $expected_status = $status_up ? 'up' : 'down';

        validate_script_output_retry(
            "grep -A 1 'Slave Interface: $device' /proc/net/bonding/$bond_name",
            sub { m/MII Status: $expected_status/ }
        );
    }
}

sub test_bonding_mode {
    my ($self, $nics_ref, $miimon, $bond_name, $bond_mode, $description) = @_;
    my @nics = @$nics_ref;

    select_serial_terminal;

    delete_existing_connections;

    create_bond($bond_name, $bond_mode, $miimon);
    add_devices_to_bond($bond_name, @nics);

    assert_script_run "nmcli con up $bond_name";

    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;
    check_connectivity $bond_name;

    # Validate that all NICs are "up"
    validate_bond_mode_and_slaves($bond_name, $description, [map { [$_, 1] } @nics]);

    # Testing failover for each NIC
    test_failover($bond_mode, $bond_name, $_, $description, \@nics) for @nics;

    delete_existing_connections;
}

sub run {
    my ($self) = @_;

    my $bond_name = "bond0";
    my $miimon = 200;
    my @nics = get_nics($bond_name);

    record_info(scalar(@nics) . " NICs Detected", join(', ', @nics));

    my @bond_modes = (
        ['balance-rr', 'load balancing (round-robin)'],
        ['active-backup', 'fault-tolerance (active-backup)'],
        ['balance-xor', 'load balancing (xor)'],
        ['broadcast', 'fault-tolerance (broadcast)'],

        # For mode=802.3ad|balance-tlb|balance-alb the switch must have support for mode and it has to be enabled on the switch
        # ['802.3ad', '802.3ad'],
        # ['balance-tlb',   'balance-tlb'],
        # ['balance-alb',   'balance-alb']
    );

    foreach my $mode_info (@bond_modes) {
        my ($bond_mode, $description) = @$mode_info;
        record_info("Testing Bonding Mode: $bond_mode", $description);
        test_bonding_mode($self, \@nics, $miimon, $bond_name, $bond_mode, $description);
    }
}

1;
