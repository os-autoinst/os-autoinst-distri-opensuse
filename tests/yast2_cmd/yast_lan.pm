# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-network
# Summary: yast lan in cli, creates, edits and deletes device and lists and
# shows details of the device
# - Installs yast2-network
# - Adds a vlan device on interface eth0
# - Display configuration summary for a lan interface with id=1
# - Change lan interface with id=1 to bootproto=dhcp
# - Delete a lan interface with id=1
# - List all available network interfaces
# Maintainer: Vit Pelcak <vpelcak@suse.cz>

use base 'y2_module_basetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_sle';

sub run {
    select_serial_terminal;
    zypper_call "in yast2-network";
    my $type = is_sle('>15') ? 'type=vlan' : '';
    validate_script_output_retry "yast lan add name=vlan50 ethdevice=eth0 $type 2>&1", sub { m/Virtual/ || m/vlan50/ }, timeout => 120;
    validate_script_output_retry 'yast lan show id=1 2>&1', sub { m/vlan50/ }, timeout => 120;
    validate_script_output_retry 'yast lan edit id=1 bootproto=dhcp 2>&1', sub { m/IP address assigned using DHCP/ || m/Configured with dhcp/ }, timeout => 120;
    assert_script_run 'yast lan delete id=1 2>&1', timeout => 120;
    validate_script_output_retry 'yast lan list 2>&1', sub { !m/Virtual/ && !m/vlan50/ }, timeout => 120;
}
1;
