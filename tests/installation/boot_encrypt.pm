# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Unlock encrypted partitions during bootup after the bootloader
#   passed, e.g. from plymouth
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "installbasetest";
use utils;
use testapi;
use version_utils qw(is_leap is_sle is_leap_micro is_sle_micro);
use bootloader_setup qw(stop_grub_timeout);

sub run {
    # With newer grub2 (in TW only currently), entering the passphrase in GRUB2
    # is enough. The key is passed on during boot, so it's not asked for
    # a second time.
    return if is_boot_encrypted && !is_leap && !is_sle && !is_leap_micro && !is_sle_micro;

    unlock_if_encrypted(check_typed_password => 1);
    record_info("edw4", "edw");
}

1;

