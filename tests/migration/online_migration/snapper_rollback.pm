# SLE12 online migration tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper
# Summary: Conduct a rollback after migration back to previous system
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use power_action_utils 'power_action';
use version_utils 'is_desktop_installed';
use migration 'check_rollback_system';

sub run {
    my ($self) = @_;

    if (!check_screen 'linux-login', 200) {    # nocheck: old code, should be updated
        assert_screen 'displaymanager', 90;
    }
    select_console 'root-console';
    script_run "snapper rollback";

    # reboot into the system before online migration
    power_action('reboot', textmode => 1, keepconsole => 1);
    $self->wait_boot(textmode => !is_desktop_installed);
    select_console 'root-console';

    check_rollback_system;
}

1;
