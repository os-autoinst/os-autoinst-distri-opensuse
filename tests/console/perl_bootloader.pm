# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test the perl-Bootloader package by generating the initrd,
#          calling update-bootloader and rebooting the host
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base 'opensusebasetest';
use testapi;
use strict;
use warnings;
use utils 'zypper_call';
use power_action_utils 'power_action';
use version_utils 'is_sle';

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

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
