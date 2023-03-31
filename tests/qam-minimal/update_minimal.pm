# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
use power_action_utils qw(power_action);
use qam;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    quit_packagekit;

    capture_state('between-after');

    assert_script_run("zypper lr | grep TEST_");

    zypper_call("ref");

    fully_patch_system;
    capture_state('after', 1);

    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => get_var('BOOTLOADER_TIMEOUT', 200));
    select_serial_terminal;
}

sub test_flags {
    return {fatal => 1};
}

1;
