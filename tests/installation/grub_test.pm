# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle grub menu after reboot
# - Handle grub2 to boot from hard disk (opposed to installation)
# - Handle passphrase for encrypted disks
# - Handle booting of snapshot or XEN, acconding to BOOT_TO_SNAPSHOT or XEN
# - Append kernel options if set with GRUB_KERNEL_OPTION_APPEND
# Tags: poo#9716, poo#10286, poo#10164
# Maintainer: Martin Kravec <mkravec@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use grub_utils qw(grub_test);

sub run {
    grub_test();
}

sub test_flags {
    return {fatal => 1};
}

1;
