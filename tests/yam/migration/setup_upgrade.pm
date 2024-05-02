# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Makes preprations for migration: version swap, update ttys and notify
# to not boot from hard disk.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use migration 'reset_consoles_tty';

sub run {
    # Save the initial/origin version of the product in order to restore later if needed
    set_var('VERSION_1', get_var('VERSION'));

    # Change version to the secondary/target one
    set_var('VERSION', get_var('VERSION_2'));
    record_info('Version', 'VERSION=' . get_var('VERSION'));

    # tty assignation might differ between product versions
    reset_consoles_tty();

    # Boot from Hard Disk will not be selected in boot screen
    set_var('BOOT_HDD_IMAGE', 0);
}

1;
