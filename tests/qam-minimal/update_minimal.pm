# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: QAM Minimal test in openQA
#    it prepares minimal instalation, boot it, install tested incident , try
#    reboot and update system with all released updates.
#
#    with QAM_MINIMAL=full it also installs gnome-basic, base, apparmor and
#    x11 patterns and reboot system to graphical login + start console and
#    x11 tests
# Maintainer: Ondřej Súkup <osukup@suse.cz>

use strict;
use warnings;
use base "opensusebasetest";

use utils;
use power_action_utils 'prepare_system_shutdown';
use qam;
use testapi;

sub run {
    my ($self) = @_;
    select_console 'root-console';

    pkcon_quit;

    capture_state('between-after');

    assert_script_run("zypper lr | grep TEST_");

    zypper_call("ref");

    fully_patch_system;
    capture_state('after', 1);

    prepare_system_shutdown;
    type_string "reboot\n";
    $self->wait_boot;
}

sub test_flags {
    return {fatal => 1};
}

1;
