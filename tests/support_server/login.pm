# Copyright 2015-2018 SUSE Linux GmbH
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot and login to the supportserver qcow2 image
# Maintainer: Pavel Sladek <psladek@suse.com>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_desktop_installed is_tumbleweed is_bootloader_grub2);

sub run {
    my ($self) = @_;
    my $timeout = (is_tumbleweed) ? 180 : 80;

    $self->override_default_bootloader unless is_bootloader_grub2;

    # we have some tests that waits for dvd boot menu timeout and boot from hdd
    # - the timeout here must cover it
    $self->wait_boot(bootloader_time => $timeout, textmode => !is_desktop_installed);

    $self->restore_default_bootloader if is_bootloader_grub2 && $self->{bootloader_overriden};

    # the supportserver image can be different version than the currently tested system
    # so try to login without use of needles
    select_serial_terminal;
}

sub override_default_bootloader {
    my ($self) = @_;
    $self->{bootloader_overriden} = 1;
    $self->{bootloader} = get_var('BOOTLOADER');
    set_var('BOOTLOADER', 'grub2');
}

sub restore_default_bootloader {
    my ($self) = @_;
    $self->{bootloader_overriden} = 0;
    set_var('BOOTLOADER', $self->{bootloader});
}

sub test_flags {
    return {fatal => 1};
}

1;
