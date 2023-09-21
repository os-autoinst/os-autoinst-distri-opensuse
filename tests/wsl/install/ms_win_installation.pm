# SUSE's openQA tests
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run an unattended Windows installation
# Maintainer: qe-c

use base 'windowsbasetest';
use strict;
use warnings;
use testapi;

sub run {
    my ($self) = @_;

    if (get_var('UEFI')) {
        assert_screen 'windows-boot';
        send_key 'spc';    # boot from CD or DVD
    }
    $self->wait_boot_windows;
}

1;
