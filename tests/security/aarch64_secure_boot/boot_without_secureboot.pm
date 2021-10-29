# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: For aarch64 system with secureboot enabled,
#          we need make sure it can boot up successfully
#          after disabling the secureboot
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#81712

use base 'opensusebasetest';
use testapi;
use strict;
use warnings;
use utils;
use power_action_utils 'power_action';
use bootloader_setup 'tianocore_disable_secureboot';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Reboot and disable secureboot
    power_action('reboot', textmode => 1);
    $self->wait_grub(bootloader_time => 200);
    $self->tianocore_disable_secureboot;
    $self->wait_boot(textmode => 1);

    # Make sure secureboot is disabled
    $self->select_serial_terminal;
    validate_script_output('mokutil --sb-state', sub { m/SecureBoot disabled/ });
}

1;
