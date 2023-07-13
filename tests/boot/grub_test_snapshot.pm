# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Select 'snapshot' boot option from grub menu
# Maintainer: okurz <okurz@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use power_action_utils 'power_action';
use utils qw(workaround_type_encrypted_passphrase reconnect_mgmt_console);
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot change_grub_config);
use Utils::Backends 'is_pvm';
use Utils::Architectures qw(is_aarch64);

sub run {
    my $self = shift;

    select_console 'root-console';
    # disable GRUB_TIMEOUT to avoid this module failed since grub menu timeout
    change_grub_config('=.*', '=-1', 'GRUB_TIMEOUT', '', 1);
    power_action('reboot', keepconsole => 1, textmode => 1);
    reset_consoles;
    reconnect_mgmt_console if is_pvm;
    $self->wait_grub(bootloader_time => 250);
    # To keep the screen at grub page
    # Refer https://progress.opensuse.org/issues/49040
    stop_grub_timeout;
    boot_into_snapshot;
}
sub test_flags {
    return {fatal => 1};
}

1;
