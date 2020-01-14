# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check PSI proc files are accessible when psi=1
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use power_action_utils 'power_action';
use bootloader_setup 'add_grub_cmdline_settings';
use Utils::Architectures 'is_s390x';

sub boot {
    my $self = shift;

    $self->wait_boot;
    # workaround for poo#54578
    if (is_s390x()) {
        select_console('root-console');
    } else {
        $self->select_serial_terminal;
    }
}

sub run {
    my $self = shift;

    $self->boot;
    assert_script_run('! cat /proc/pressure/cpu');

    add_grub_cmdline_settings('psi=1', update_grub => 1);

    power_action('reboot', textmode => 1);
    $self->boot;

    assert_script_run('cd /proc/pressure');
    assert_script_run('cat cpu memory io');
}

1;
