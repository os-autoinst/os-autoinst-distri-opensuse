# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Remove bridge network in CC system role for multi-machine test
# Maintainer: QE Security <none@suse.de>
# Tags: poo#102116

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    select_console 'root-console';

    my $bridge_info = script_output('bridge link');
    if ($bridge_info =~ /\d+:\s+(\S+):.*master\s(br\d).*/) {
        my $eth_interface = $1;
        my $br_interface = $2;
        assert_script_run("rm -f /etc/sysconfig/network/ifcfg-$br_interface");
        assert_script_run("sed -i 's/none/dhcp/' /etc/sysconfig/network/ifcfg-$eth_interface");
        assert_script_run('systemctl restart network.service');
    }
}

1;
