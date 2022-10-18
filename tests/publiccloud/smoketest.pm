# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run basic smoketest on publiccloud test instance
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $self = shift;
    select_serial_terminal;

    # Check if systemd completed sucessfully
    assert_script_run 'journalctl -b | grep "Reached target Basic System"';
    # Additional basic commands to verify the instance is healthy
    validate_script_output('echo "ping"', sub { m/ping/ });
    assert_script_run 'uname -a';
}

1;
