# SUSE's openQA tests - FIPS tests
#
# Copyright 2016-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: SquidInit
# Summary: FIPS tests for squid proxy
#
# Maintainer: QE Security <none@suse.de>

use base "basetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils qw(zypper_call systemctl);

sub run {
    my $self = shift;
    select_serial_terminal;
    # install squid package with default config
    zypper_call("in squid");
    systemctl 'enable squid';
    # Check squid status: active is the expected result
    systemctl 'start squid';
    validate_script_output('systemctl status --no-pager squid.service', sub { m/Active: active/ });
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
