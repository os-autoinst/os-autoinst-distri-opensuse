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

sub test_failover {
    my $device = shift;
    # disable one child eth, other should keep bond0 alive
    assert_script_run "ip link set dev $device down";
    script_run 'ip a';
    # networking should be still good
    assert_script_run 'ping -c1 -I bond0 conncheck.opensuse.org';
    # bring back up device
    assert_script_run "ip link set dev $device up";
}

sub run {
    my ($self) = @_;
    select_console 'root-console';
    my @devices;
    # many device can share the same id, so we'll use hash keys to dedup
    my %connections;
    # remove existing NM-managed connections (except loopback).
    foreach (split('\n', script_output 'nmcli -g DEVICE,UUID conn show --active')) {
        next if /^lo:/;    # skip loopback device
        my @item = split /:/;
        push @devices, $item[0];
        $connections{$item[1]} = 1;
    }
    assert_script_run "nmcli con delete '$_'" for keys %connections;
    # create a new bonding interface and connect the two ethernet
    assert_script_run "nmcli con add type bond ifname bond0 con-name bond0";
    assert_script_run "nmcli con add type ethernet ifname $_ master bond0" for @devices;
    # bring up bond interface
    assert_script_run "nmcli con up bond0";
    # reboot to ensure connection properly comes up at start
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_console 'root-console';
    # first connectivity check
    assert_script_run 'ping -c1 -I bond0 conncheck.opensuse.org';
    # check device failover
    test_failover $_ for @devices;
}

1;
