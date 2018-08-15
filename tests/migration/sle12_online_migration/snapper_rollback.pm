# SLE12 online migration tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Conduct a rollback after migration back to previous system
# Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;
use utils;
use version_utils 'is_desktop_installed';
use migration 'check_rollback_system';

sub run {
    my ($self) = @_;

    # login to before online migration snapshot
    # tty would not appear quite often after booting snapshot
    # it is a known bug bsc#980337
    # in this case select tty1 first then select root console
    if (!check_screen('linux-login', 200)) {
        record_soft_failure 'bsc#980337';
        send_key "ctrl-alt-f1";
        assert_screen 'tty1-selected';
    }

    select_console 'root-console';
    script_run "snapper rollback";

    # reboot into the system before online migration
    power_action('reboot');
    $self->wait_boot(textmode => !is_desktop_installed);
    select_console 'root-console';

    check_rollback_system;
}

1;
