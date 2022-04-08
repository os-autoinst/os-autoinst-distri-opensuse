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

    # Print the context of "/sys/kernel/security/lockdown" file
    my $file_cont = script_output('cat /sys/kernel/security/lockdown');
    record_info('lockdown info', "$file_cont");

    # Make sure lockdown is enabled
    validate_script_output('if grep "\[none\]" /sys/kernel/security/lockdown; then echo "FAIL"; else echo "PASS"; fi', sub { /PASS/ });
    my $result = script_run('dd if=/dev/mem count=1');
    if (!$result) {
        die('lockdown is NOT enabled');
    }
}

1;
