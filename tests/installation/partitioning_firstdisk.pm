# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: New test to take the first disk
#    Otherwise the partitioning proposal will use a free disk, which makes
#    rebooting a game of chance on real hardware
# Maintainer: Stephan Kulow <coolo@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;
use utils 'is_storage_ng';

sub take_first_disk_storage_ng {
    return unless is_storage_ng;
    send_key $cmd{guidedsetup};    # select guided setup
    assert_screen 'select-hard-disks';
    assert_and_click 'hard-disk-dev-sdb-selected';    # Unselect second drive
    assert_screen 'select-hard-disks-one-selected';
    send_key $cmd{next};
    # If drive is not formatted, we have select hard disks page
    # On ipmi we always have unformatted drive
    if (get_var('ISO_IN_EXTERNAL_DRIVE') || check_var('BACKEND', 'ipmi')) {
        assert_screen 'select-hard-disks';
        send_key $cmd{next};
    }
    assert_screen 'partition-scheme';
    send_key $cmd{next};
    # select btrfs file system
    assert_and_click 'default-root-filesystem';
    assert_and_click "filesystem-btrfs";
    assert_screen "btrfs-selected";
    send_key $cmd{next};
}

sub take_first_disk {
    # create partitioning
    send_key $cmd{createpartsetup};
    assert_screen 'prepare-hard-disk';

    wait_screen_change {
        send_key 'alt-1';
    };
    send_key 'alt-n';

    assert_screen 'use-entire-disk';
    wait_screen_change {
        send_key 'alt-e';
    };
    send_key $cmd{next};
}

sub run {
    if (is_storage_ng) {
        take_first_disk_storage_ng;
        return 1;
    }
    take_first_disk;
}

1;
# vim: set sw=4 et:
