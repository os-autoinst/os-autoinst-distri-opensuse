# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perl-Bootloader dracut
# Summary: Test the perl-Bootloader package by generating the initrd,
#          calling update-bootloader and rebooting the host
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils 'zypper_call';
use power_action_utils 'power_action';
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    if (script_run 'rpm -q perl-Bootloader' == 1) {
        zypper_call 'in perl-Bootloader';
    }
    assert_script_run 'mkinitrd';
    assert_script_run 'update-bootloader';

    if (is_sle('>=12-SP2')) {
        validate_script_output('pbl --show', sub { /grub2/ });
    }

    power_action('reboot', textmode => 1);
    $self->wait_boot;
}

1;
