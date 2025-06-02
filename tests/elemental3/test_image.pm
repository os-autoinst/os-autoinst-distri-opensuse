# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test installation and boot of Elemental ISO
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base 'opensusebasetest';
use strict;
use warnings;

use testapi;
use power_action_utils qw(power_action);
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures;

sub run {
    my ($self) = @_;

    # For HDD image boot
    if (check_var('IMAGE_TYPE', 'disk')) {
        # Wait for GRUB and select default entry
        $self->wait_grub();
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);
        save_screenshot();
    }

    # Wait for login screen
    assert_screen('linux-login');
}

sub test_flags {
    return {fatal => 1};
}

1;
