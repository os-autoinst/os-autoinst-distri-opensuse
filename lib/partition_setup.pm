# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package partition_setup;

use base Exporter;
use Exporter;

use strict;
use testapi;
use utils 'is_storage_ng';

our @EXPORT = qw(wipe_existing_partitions addpart addlv);

my %role = qw(
  OS alt-o
  data alt-d
  swap alt-s
  raw alt-a
);

sub wipe_existing_partitions_storage_ng {
    send_key_until_needlematch "expert-partitioner-hard-disks", 'right';
    wait_still_screen 2;
    # Remove partition
    send_key 'alt-d';
    # Confirm in pop-up
    assert_screen "delete-all-partitions-confirm";
    send_key 'alt-t';
    # Verify removed
    send_key_until_needlematch "expert-partitioner-vda", 'right';
    assert_screen 'expert-partitioner-unpartitioned';
}

sub wipe_existing_partitions {
    assert_screen('release-notes-button');
    send_key match_has_tag('bsc#1054478') ? 'alt-x' : $cmd{expertpartitioner};
    assert_screen 'expert-partitioner';
    wait_still_screen;
    #Use storage ng
    if (is_storage_ng) {
        wipe_existing_partitions_storage_ng;
        return;
    }
    for (1 .. 4) {
        send_key 'right';    # select vda hard disk
    }

    # empty disk partitions by creating new partition table
    send_key 'alt-x';        # expert menu
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';          # create new partition table
    unless (get_var('UEFI') || check_var('BACKEND', 's390x')) {    # only GPT partition table
        assert_screen 'partition-table-MSDOS-selected';
        send_key 'alt-o';                                          # OK
    }
    assert_screen 'partition-create-new-table';
    send_key 'alt-y';                                              # yes
}

sub addpart {
    my (%args) = @_;
    assert_screen 'expert-partitioner';
    send_key $cmd{addpart};
    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
    # also doesn't appear with storage-ng
    if (is_storage_ng && check_screen 'partition-size', 0) {
        record_soft_failure 'bsc#1055743';
    }
    unless (get_var('UEFI') || check_var('BACKEND', 's390x') || is_storage_ng) {
        assert_screen 'partitioning-type';
        send_key $cmd{next};
    }
    assert_screen 'partition-size';
    if ($args{size}) {
        if (is_storage_ng) {
            # maximum size is selected by default
            send_key 'alt-c';
            assert_screen 'partition-custom-size-selected';
            send_key 'alt-s';
        }
        for (1 .. 10) {
            send_key 'backspace';
        }
        type_string $args{size} . 'mb';
    }
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key $role{$args{role}};
    send_key $cmd{next};
    assert_screen 'partition-format';
    if ($args{format}) {
        if ($args{format} eq 'donotformat') {
            send_key $cmd{donotformat};
            send_key 'alt-u';
        }
        else {
            send_key 'alt-a' if is_storage_ng;    # Select to format partition, not selected by default
            wait_still_screen 1;
            send_key 'alt-s';
            send_key_until_needlematch "partition-selected-$args{format}-type", 'down';
        }
    }
    if ($args{fsid}) {                            # $args{fsid} will describe needle tag below
        send_key 'alt-i';                         # select File system ID

        # Due to bsc#1062465 cannot go from top to bottom on storage-ng
        send_key 'end';
        send_key_until_needlematch "partition-selected-$args{fsid}-type", 'up';
    }
    if ($args{mount}) {
        send_key 'alt-m';
        type_string "$args{mount}";
    }
    if ($args{encrypt}) {
        send_key $cmd{encrypt};
        assert_screen 'partition-lvm-encrypt';
        send_key $cmd{next};
        assert_screen 'partition-lvm-password-prompt';
        send_key 'alt-e';    # select password field
        type_password;
        send_key 'tab';
        type_password;
    }
    send_key((is_storage_ng) ? $cmd{next} : $cmd{finish});
}

sub addlv {
    my (%args) = @_;
    send_key $cmd{addpart};
    send_key 'down';
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';    # create logical volume
    assert_screen 'partition-lv-type';
    type_string $args{name};
    send_key $cmd{next};
    assert_screen 'partition-lv-size';
    if ($args{size}) {    # use default max size if not defined
        send_key 'alt-c';    # custom size
        type_string $args{size} . 'mb';
    }
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key $role{$args{role}};    # swap role
    send_key $cmd{next};
    assert_screen 'partition-format';
    send_key $cmd{finish};
}

1;
# vim: set sw=4 et:
