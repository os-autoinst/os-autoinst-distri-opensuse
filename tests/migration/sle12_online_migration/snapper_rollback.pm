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
use warnings;
use testapi;
use power_action_utils 'power_action';
use version_utils 'is_desktop_installed';
use migration qw(check_rollback_system boot_into_ro_snapshot);

sub run {
    my ($self) = @_;

    boot_into_ro_snapshot;
    select_console 'root-console';
    script_run "snapper rollback";

    # reboot into the system before online migration
    power_action('reboot', textmode => 1, keepconsole => 1);
    $self->wait_boot(textmode => !is_desktop_installed);
    select_console 'root-console';

    check_rollback_system;
}

1;
