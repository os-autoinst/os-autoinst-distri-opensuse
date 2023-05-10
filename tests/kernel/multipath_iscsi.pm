# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Smoke test for multipath over iscsi
# - Install open-iscsi
# - Start iscsid and multipathd services and check status
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use iscsi;
use serial_terminal 'select_serial_terminal';

sub run {
    # Set default variables for iscsi iqn and target
    my $iqn = get_var("ISCSI_IQN", "iqn.2016-02.de.openqa");
    my $target = get_var("ISCSI_TARGET", "10.0.2.1");

    select_serial_terminal;

    # Install iscsi
    zypper_call("in open-iscsi");

    # Start isci amd multipath services
    systemctl 'start iscsid';
    systemctl 'start multipathd';
    systemctl 'status multipathd';

    # Connect to iscsi server and check paths
    iscsi_discovery $target;
    iscsi_login $iqn, $target;
    my $times = 10;
    ($times-- && sleep 1) while (script_run('multipathd -k"show multipaths status" | grep active') && $times);
    die "multipath not ready even after waiting 10s" unless $times;
    assert_script_run("multipathd -k\"show multipaths status\"");
    # Connection cleanup
    iscsi_logout $iqn, $target;
}

1;
