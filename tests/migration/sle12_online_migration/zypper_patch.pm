# SLE12 online migration tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Fully patch the system before conducting an online migration
# Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use power_action_utils 'power_action';
use version_utils 'is_desktop_installed';
use migration;
use qam;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    add_test_repositories;
    fully_patch_system;
    remove_ltss;
    power_action('reboot', keepconsole => 1, textmode => 1);
    $self->wait_boot(textmode => !is_desktop_installed, bootloader_time => 300, ready_time => 600);
    $self->setup_migration;
}

sub test_flags {
    return {fatal => 1};
}

1;
