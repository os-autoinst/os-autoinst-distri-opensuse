# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pciutils mstflint
# Summary: Mellanox Link protocol config
# This configures the interfaces according to the
# variable MLX_PROTOCOL. By default ETH if not set.
# Set MLX_SRIOV=1 and MLX_NUM_VFS=<num> to enable
# SR-IOV and create <num> virtual functions.
# Maintainer: Jose Lausuch <jalausuch@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils;
use ipmi_backend_utils;
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    my $protocol = get_var('MLX_PROTOCOL', 2);

    # allow to configure SR-IOV and enable virtual functions
    my $sriov_en = get_var('MLX_SRIOV', 0);
    my $num_vfs = get_var('MLX_NUM_VFS', 0);

    if ($sriov_en == 0 && $num_vfs > 0) {
        diag "MLX_SRIOV=0: set MLX_NUM_VFS to 0 as well";
        $num_vfs = 0;
    }

    # right now, this code will only do something reasonable if we
    # run on a baremetal machine (and thus on IPMI backend)
    return unless is_ipmi;

    select_serial_terminal;

    # install dependencies
    zypper_call('--quiet in pciutils mstflint', timeout => 200);

    my @devices = split(' ', script_output("lspci | grep -i infiniband.*mellanox |cut  -d ' ' -f 1"));

    die "There is no Mellanox card here" if !@devices;

    # no need to configure the devices if already in the right mode
    my $ports_configured = script_output("mstconfig -d $devices[0] q | grep LINK_TYPE | grep -c $protocol");
    return if $ports_configured == scalar @devices;

    # Change Link protocol for all devices
    foreach (@devices) {
        record_info("INFO", "Wanted Link protocol for $_ is $protocol");

        assert_script_run("mstconfig -y -d $_ set LINK_TYPE_P1=$protocol LINK_TYPE_P2=$protocol SRIOV_EN=$sriov_en NUM_OF_VFS=$num_vfs");
    }
    # verify our new settings
    $ports_configured = script_output("mstconfig -d $devices[0] q | grep LINK_TYPE | grep -c $protocol");
    die "unable to configure all ports!" unless $ports_configured == scalar @devices;

    # Reboot system
    power_action('reboot', textmode => 1, keepconsole => 1);

    # make sure we wait until the reboot is done
    select_console 'sol', await_console => 0;
    assert_screen('linux-login', 1800);
}

sub test_flags {
    return {fatal => 1};
}

1;
