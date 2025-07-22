# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Reboot from the running system into the bootloader
# Maintainer: Fabian Vogt <fvogt@suse.com>

use base 'opensusebasetest';
use testapi;
use power_action_utils qw(power_action);
use utils qw(unlock_bootloader);

sub run {
    # While it makes sense to eject the CD here after install,
    # this has always been commented out. No idea why.
    # eject_cd
    power_action 'reboot';
    unlock_bootloader;
}

1;

