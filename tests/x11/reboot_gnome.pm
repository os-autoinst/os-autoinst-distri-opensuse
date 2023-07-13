# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Reboot GNOME with or without authentication and ensure proper boot
# - Call system reboot, keep console
# - Wait until system fully boots (bootloader, login prompt)
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use power_action_utils 'power_action';
use utils 'is_boot_encrypted';

sub run {
    my ($self) = @_;
    # 'keepconsole => 1' is workaround for bsc#1044072
    # Poo#80184, it's not suitable to keep console for s390x after reboot.
    power_action('reboot', keepconsole => (is_s390x) ? 0 : 1);

    # In 88388900d2dfe267230972c6905b3cc18fb288cf the wait timeout was
    # bumped, due to tianocore being a bit slower, this brings this module
    # in sync
    # 12/2019: Increasing from 400 to 600 since more seems to be required.
    my $bootloader_timeout = (is_boot_encrypted || is_aarch64) ? 600 : 300;

    $self->wait_boot(bootloader_time => $bootloader_timeout);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

