# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run basic smoketest on publiccloud test instance
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Check if systemd completed sucessfully
    assert_script_run 'journalctl -b | grep "Reached target Basic System"';
    # Additional basic commands to verify the instance is healthy
    validate_script_output('echo "ping"', sub { m/ping/ });
    assert_script_run 'uname -a';
}

1;
