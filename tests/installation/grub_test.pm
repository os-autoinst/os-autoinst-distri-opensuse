# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handle grub menu after reboot
# - Handle grub2 to boot from hard disk (opposed to installation)
# - Handle passphrase for encrypted disks
# - Handle booting of snapshot or XEN, according to BOOT_TO_SNAPSHOT or XEN
# - Enable plymouth debug if product if GRUB_KERNEL_OPTION_APPEND is set,
# or product is sle, aarch64 and PLYMOUTH_DEBUG is set
# Tags: poo#9716, poo#10286, poo#10164
# Maintainer: Martin Kravec <mkravec@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use grub_utils qw(grub_test);

sub run {
    grub_test();
}

sub test_flags {
    return {fatal => 1};
}

1;
