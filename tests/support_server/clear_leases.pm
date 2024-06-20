# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: remove DHCP leases DB from support server
# Maintainer: Alvaro Carvajal <acarvajal@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'systemctl';

sub run {
    my ($self) = @_;
    systemctl 'stop dhcpd';
    my $leases = '/var/lib/dhcp/db/dhcpd.leases';
    assert_script_run "cp -f $leases ${leases}~";
    assert_script_run "> $leases";
}

1;
