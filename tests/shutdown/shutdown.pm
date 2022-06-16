# Copyright 2015-2018 SUSE Linux Products GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Shut down the system
# - Poweroff system
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use power_action_utils 'power_action';
use utils;

sub run {
    select_console 'root-console';
    script_run('cat /etc/os-release');
    select_console 'x11';
    power_action('poweroff');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    select_console('log-console');
    # check systemd jobs still running in background, these jobs
    # might slow down or block shutdown progress
    systemctl 'list-jobs';
}

1;
