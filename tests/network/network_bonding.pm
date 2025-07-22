# SUSE's openQA tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test network bonding capability and connectivity
# Maintainer: QE Core <qe-core@suse.de>

use base "consoletest";
use testapi;
use power_action_utils "power_action";
use utils qw(validate_script_output_retry);
use serial_terminal qw(select_serial_terminal);
use network_utils qw(get_nics cidr_to_netmask is_nm_used is_wicked_used check_connectivity_to_host_with_retry delete_all_existing_connections create_bond add_interfaces_to_bond set_nics_link_speed_duplex);
use lockapi;
use utils;
use console::ovs_utils;
use version_utils;

my $target_ip = "10.0.2.101";

sub configure_bond_interface_network {
    my ($bond_name) = @_;

    if (is_nm_used()) {
        # NetworkManager configuration using DHCP
        assert_script_run "nmcli con modify $bond_name ipv4.method auto";
        assert_script_run "nmcli con up $bond_name";
    }

    if (is_wicked_used()) {
        # Wicked configuration: setting to DHCP
        assert_script_run "touch /etc/sysconfig/network/ifcfg-$bond_name";
        assert_script_run "echo 'BOOTPROTO=dhcp' >> /etc/sysconfig/network/ifcfg-$bond_name";
        assert_script_run "echo 'STARTMODE=auto' >> /etc/sysconfig/network/ifcfg-$bond_name";

        my $route_config_file = "/etc/sysconfig/network/ifroute-$bond_name";

        # Remove any existing route configuration since DHCP handles routes
        script_run "rm -f $route_config_file";

        # Restart Wicked to apply the DHCP configuration
        systemctl 'restart wicked';
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

    check_connectivity_to_host_with_retry($bond_name, $target_ip);

    assert_script_run "ip link set dev $device up";
    systemctl 'restart wicked' if is_wicked_used();
}

sub validate_bond_mode_and_slaves {
    my ($bond_name, $description, $devices_ref) = @_;

    assert_script_run "cat /proc/net/bonding/$bond_name | grep 'Mode:' | grep '$description'";

    foreach my $device_info (@$devices_ref) {
        my ($device, $status_up) = @$device_info;
        my $expected_status = $status_up ? 'up' : 'down';

        validate_script_output_retry(
            "grep -A 1 'Slave Interface: $device' /proc/net/bonding/$bond_name",
            sub { m/MII Status: $expected_status/ },
            type_command => 1
        );
    }
}

sub test_bonding_mode {
    my ($self, $nics_ref, $miimon, $bond_name, $bond_mode, $description) = @_;
    my @nics = @$nics_ref;

    select_serial_terminal;

    delete_all_existing_connections;

    create_bond($bond_name, {
            mode => $bond_mode,
            miimon => $miimon,
            autoconnect_slaves => 1
    });

    add_interfaces_to_bond($bond_name, @nics);
    configure_bond_interface_network($bond_name);

    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;

    # Because settings don't survive reboot, to fix bug on Network Manager
    set_nics_link_speed_duplex({
            nics => \@nics,
            speed => 1000,    # assuming a speed of 1000 Mbps
            duplex => 'full',    # assuming full duplex
            autoneg => 'off'    # assuming autoneg is off
    });

    check_connectivity_to_host_with_retry($bond_name, $target_ip);

    # Validate that all NICs are "up"
    validate_bond_mode_and_slaves($bond_name, $description, [map { [$_, 1] } @nics]);

    # Testing failover for each NIC
    test_failover($bond_mode, $bond_name, $_, $description, \@nics) for @nics;

    delete_all_existing_connections;
}

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $bond_name = "bond0";
    my $miimon = 200;
    my @nics = get_nics([$bond_name]);

    my @bond_modes = (
        ['balance-rr', 'load balancing (round-robin)'],
        ['active-backup', 'fault-tolerance (active-backup)'],
        ['balance-xor', 'load balancing (xor)'],
        ['broadcast', 'fault-tolerance (broadcast)'],
        ['802.3ad', 'IEEE 802.3ad Dynamic link aggregation'],
        ['balance-tlb', 'transmit load balancing'],
        ['balance-alb', 'adaptive load balancing']
    );

    foreach my $mode_info (@bond_modes) {
        my ($bond_mode, $description) = @$mode_info;
        record_info("Testing Bonding Mode: $bond_mode", $description);
        test_bonding_mode($self, \@nics, $miimon, $bond_name, $bond_mode, $description);
    }

    barrier_wait "BONDING_TESTS_DONE";
}

1;
