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
use testapi qw(check_var get_var record_info);

sub run {
    # In TW (Staging:M only for now), entering the passphrase in GRUB2
    # is enough. The key is passed on during boot, so it's not asked for
    # a second time.
    return if is_boot_encrypted && check_var('VERSION', 'Staging:M');

    unlock_if_encrypted(check_typed_password => 1);
}

1;

