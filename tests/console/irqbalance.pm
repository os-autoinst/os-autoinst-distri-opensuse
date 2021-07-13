# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: irqbalance
# Summary: Test irqbalance runs as service as well as standalone
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use warnings;
use base "consoletest";
use strict;
use testapi qw(is_serial_terminal :DEFAULT);
use utils qw(systemctl zypper_call clear_console);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Return when balancing is ineffective on system with a single cpu
    zypper_call("in coreutils") if (script_run("which nproc") != 0);
    if (script_output('nproc') <= 1) {
        record_info("Low CPUs amount", "Balancing is ineffective on systems with a single cpu");
        return;
    }

    # Install irqbalance
    zypper_call("in irqbalance") if (script_run("which irqbalance") != 0);

    # Enable and start irqbalance.service if needed
    systemctl('start irqbalance.service')  if (script_run('systemctl -n is-active irqbalance.service'));
    systemctl('enable irqbalance.service') if (script_run('systemctl -n is-enabled irqbalance.service'));

    # Check that the irqbalance.service is running
    systemctl('is-active irqbalance.service');
    systemctl('status irqbalance.service');

    # Run the irqbalance in oneshot debug modes
    assert_script_run("irqbalance --oneshot --debug", 360);

    assert_script_run("cat /proc/interrupts");

    # Clear the remains from background commands
    clear_console if !is_serial_terminal;
}

1;
