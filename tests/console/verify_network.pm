# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify basic network configuration
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'y2_module_consoletest';
use strict;
use warnings;

use testapi;
use utils;
use scheduler;
use cfg_files_utils 'validate_cfg_file';

sub run {
    select_console 'root-console';
    my ($nm, $dev, $cfg_files) = @{get_test_suite_data()->{network}}{
        qw(network_manager device config_files)};

    # check device UP (or UNKNOWN for some machines)
    if (script_run("ip link show dev $dev | grep -E 'state (UP|UNKNOWN)'")) {
        die "Network device '$dev' should be UP (or UNKNOWN)";
    }
    # check IPv6 addresses in use
    die 'IPv6 address not assigned' if script_output("ip -6 addr show dev $dev") eq '';
    # check assigned to the default zone (public)
    if (script_output("firewall-cmd --list-interfaces") ne "$dev") {
        die "Network device '$dev' not assigned to default zone";
    }

    # check network manager
    if (script_run("readlink /etc/systemd/system/network.service | grep $nm")) {
        die "Network manager '$nm' not used";
    }

    # check configuration files
    validate_cfg_file($cfg_files);
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    upload_logs for (@{get_test_suite_data()->{network}->{config_files}});
}

1;
