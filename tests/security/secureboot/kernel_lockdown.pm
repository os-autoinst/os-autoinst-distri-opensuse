# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Verify that if we are "secure booted" that kernel lockdown is enabled
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#109611

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Make sure system is secureboot enabled
    validate_script_output('mokutil --sb-state', sub { m/SecureBoot enabled/ });

    validate_script_output('cat /sys/kernel/security/lockdown', sub { /\[integrity\]/ });
    if (script_run('dd if=/dev/mem count=1') == 0) {
        die('lockdown is NOT enabled');
    }
}

1;
