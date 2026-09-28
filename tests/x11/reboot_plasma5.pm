# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Ensure system can reboot from plasma5 session
# Maintainer: Oliver Kurz <okurz@suse.de>

use Mojo::Base 'x11test';
use testapi;
use utils;
use power_action_utils;
use x11utils qw(update_x11_vt);

sub run {
    my ($self) = @_;
    power_action 'reboot';
    $self->wait_boot(bootloader_time => 300);
    # Ensure the desktop runner is reactive again before going into other test
    # modules
    # https://progress.opensuse.org/issues/30805
    $self->check_desktop_runner;
    # also prevent key repetition errors
    $self->disable_key_repeat;

    # After reboot and login the graphical session might be on a different VT again.
    update_x11_vt;
}

sub test_flags {
    return {milestone => 1};
}

1;

