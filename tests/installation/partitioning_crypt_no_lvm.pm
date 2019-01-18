# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test installation with encrypted drive, but without lvm
# This is possible only with storage-ng.
#
# Tags: poo#26810, fate#320182
#
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use strict;
use warnings;
use base 'y2logsstep';
use testapi;
use version_utils 'is_storage_ng';
use partition_setup 'enable_encryption_guided_setup';

sub run {
    die "Encrypting without lvm is only possible with storage_ng" unless is_storage_ng;

    send_key $cmd{guidedsetup};    # select guided setup
    assert_screen 'inst-partitioning-scheme';

    # Enable encryption
    enable_encryption_guided_setup;
    # Verify filesystem
    assert_screen 'inst-filesystem-options';
    # btrfs should be selected by default
    assert_screen 'btrfs-selected';
    send_key $cmd{next};

    assert_screen 'inst-encrypt-no-lvm';
}

1;

