# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: yast lan in cli, creates, edits and deletes device and lists and
# shows details of the device
# Maintainer: Vit Pelcak <vpelcak@suse.cz>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    zypper_call "in yast2-network";
    my $type = is_sle('15+') ? 'type=vlan' : '';
    validate_script_output "yast lan add name=vlan50 ethdevice=eth0 $type 2>&1", sub { m/Virtual/ };
    validate_script_output 'yast lan show id=1 2>&1',                            sub { m/vlan50/ };
    validate_script_output 'yast lan edit id=1 bootproto=dhcp 2>&1',             sub { m/IP address assigned using DHCP/ }, 60;
    validate_script_output 'yast lan delete id=1 2>&1',                          sub { m/deleted/ };
    validate_script_output 'yast lan list 2>&1',                                 sub { !m/Virtual/ };
}
1;
