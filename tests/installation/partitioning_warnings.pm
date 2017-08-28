# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create small root partition (11GB) to test 'too small filesystem for snapshots' warning
#          missing swap warning and on UEFI missing /boot/efi partition
#          https://progress.opensuse.org/issues/16570 https://fate.suse.com/320416
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use warnings;
use base 'y2logsstep';
use testapi;
use partition_setup;
use utils 'is_storage_ng';

sub run {
    wipe_existing_partitions;
    if (check_var('ARCH', 's390x')) {    # s390x need /boot/zipl on ext partition
        addpart(role => 'OS', size => 500, format => 'ext2', mount => '/boot');
    }
    elsif (check_var('ARCH', 'ppc64le')) {    # ppc64le need PReP /boot
        addpart(role => 'raw', size => 500, fsid => 'PReP');
    }
    # create small enough partition (11GB) to get warning
    addpart(role => 'OS', size => 11000, format => 'btrfs');

    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    if (is_storage_ng) {
        assert_screen 'partitioning-edit-proposal-button';
        record_soft_failure 'bsc#1055744';
    }
    else {
        # expect partition setup warning pop-ups
        assert_screen 'partition-warning-too-small-for-snapshots';
        wait_screen_change { send_key 'alt-y' };    # yes
    }
    if (get_var('UEFI')) {
        assert_screen 'partition-warning-no-efi-boot';
        wait_screen_change { send_key 'alt-y' };    # yes
    }
    if (is_storage_ng && !check_screen('partitioning-edit-proposal-button', 0)) {
        record_soft_failure 'bsc#1055747';
    }
    else {
        assert_screen 'partition-warning-no-swap';
        wait_screen_change { send_key 'alt-y' };    # yes
    }
}

1;
# vim: set sw=4 et:
