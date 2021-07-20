# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    zypper_call "in yast2-network";
    my $type = is_sle('>15') ? 'type=vlan' : '';
    validate_script_output "yast lan add name=vlan50 ethdevice=eth0 $type 2>&1", sub { m/Virtual/ || m/vlan50/ }, timeout => 60;
    validate_script_output 'yast lan show id=1 2>&1', sub { m/vlan50/ };
    validate_script_output 'yast lan edit id=1 bootproto=dhcp 2>&1', sub { m/IP address assigned using DHCP/ || m/Configured with dhcp/ }, 60;
    assert_script_run 'yast lan delete id=1 2>&1';
    validate_script_output 'yast lan list 2>&1', sub { !m/Virtual/ && !m/vlan50/ };
}
1;
