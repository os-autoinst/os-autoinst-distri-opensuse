# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: cronie
# Summary: Check for CRON daemon
# - check if cron is enabled
# - check if cron is active
# - check cron status
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    # check if cronie is installed, enabled and running
    assert_script_run 'rpm -q cronie';
    systemctl 'is-enabled cron';
    systemctl 'is-active cron';
    systemctl 'status cron';
}

1;

