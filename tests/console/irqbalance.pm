# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: irqbalance
# Summary: Test irqbalance runs as service as well as standalone
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use warnings;
use base "consoletest";
use strict;
use testapi qw(is_serial_terminal :DEFAULT);
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl zypper_call clear_console);

sub run {
    my $self = shift;
    select_serial_terminal;

    # Return when balancing is ineffective on system with a single cpu
    my $nproc = script_output('cat /proc/cpuinfo | grep processor | wc -l');
    die("Balancing is ineffective on systems with a single cpu (nproc=$nproc)") unless ($nproc > 1);

    zypper_call("in irqbalance");
    systemctl('enable --now irqbalance.service');

    # Generate CPU load
    assert_script_run('dd if=/dev/urandom of=/dev/null count=30 bs=16M iflag=fullblock', 90);

    # Test that local timer interrupts are distributed over CPUs
    my @locs = split(' ', script_output("grep 'LOC' /proc/interrupts | sed -E -e 's/[[:blank:]]+/ /g' | cut -d' ' -f 2-\$((${nproc}+1))"));
    for (my $i = 0; $i < $nproc; $i++) {
        die("The value of local timer interrupts for CPU" . ($i + 1) . " is 0") unless ($locs[$i] > 0);
    }

    systemctl('stop irqbalance.service');

    # Test that irqbalance succeeds as standalone application
    assert_script_run('irqbalance --oneshot --debug', 360);

    # start irqbalance.service again
    systemctl('start irqbalance.service');

    # Clear the remains from background commands
    clear_console if !is_serial_terminal;
}

1;
