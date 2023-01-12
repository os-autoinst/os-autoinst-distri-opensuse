# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: xterm
# Summary: Basic functionality of xterm terminal emulator
# - Launch xterm
# - Type "If you can see this text xterm is working" in the terminal
# Maintainer: QE Core <qe-core@suse.de>

use base "x11test";
use strict;
use warnings;
use testapi;
use power_action_utils qw(power_action);
use version_utils qw(is_leap);

sub run {
    my ($self) = @_;
    # workaround for bsc#1205518
    if (is_leap) {
        record_info 'workaround', 'bsc#1205518 - Rebooting the VM to avoid the gnome issue';
        power_action('reboot', textmode => 1);
        $self->wait_boot(bootloader_time => 300);
    }
    select_console 'x11';
    $self->test_terminal('xterm');
}

1;
