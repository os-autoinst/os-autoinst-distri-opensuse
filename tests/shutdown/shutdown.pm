# Copyright 2015-2018 SUSE Linux Products GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Shut down the system
# - Poweroff system
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use base "opensusebasetest";
use testapi;
use power_action_utils qw(power_action check_bsc1215132);
use utils;
use serial_terminal qw(select_serial_terminal);

sub run {
    my $self = shift;
    # There's a kernel bug in MLS8. bsc#1259131
    # Wrong encoding when shutting down after kernel update
    if (check_var("VERSION", "mls8")) {
        select_serial_terminal;
        record_soft_failure("bsc#1259131 - Wrong encoding in MLS8 when shutting down after kernel update");
    } else {
        select_console("root-console");
    }
    systemctl 'list-timers --all';
    power_action('poweroff');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    check_bsc1215132();
    $self->SUPER::post_fail_hook;
    select_console('log-console');
    # check systemd jobs still running in background, these jobs
    # might slow down or block shutdown progress
    systemctl 'list-jobs';
}

1;
