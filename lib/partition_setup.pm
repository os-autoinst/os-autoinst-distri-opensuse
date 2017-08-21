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

our @EXPORT = qw(wipe_existing_partitions addpart addlv);

my %role = qw(
  OS alt-o
  data alt-d
  swap alt-s
  raw alt-a
);

sub wipe_existing_partitions {
    assert_screen('release-notes-button');
    send_key match_has_tag('bsc#1054478') ? 'alt-x' : $cmd{expertpartitioner};
    assert_screen 'expert-partitioner';
    wait_still_screen;
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
    unless (get_var('UEFI') || check_var('BACKEND', 's390x')) {    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
        assert_screen 'partitioning-type';
        send_key $cmd{next};
    }
    assert_screen 'partition-size';
    if ($args{size}) {
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
            send_key 'alt-s';
            send_key_until_needlematch "partition-selected-$args{format}-type", 'down';
        }
    }
    if ($args{fsid}) {    # $args{fsid} will describe needle tag below
        send_key 'alt-i';    # select File system ID
        send_key_until_needlematch "partition-selected-$args{fsid}-type", 'down';
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
    send_key $cmd{finish};
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
