# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Power off Elemental OS server
# Maintainer: elemental@suse.de

use base 'opensusebasetest';
use strict;
use warnings;

use testapi;
use power_action_utils qw(power_action);
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # It's the end, power off!
    power_action('poweroff', keepconsole => 1, textmode => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;
