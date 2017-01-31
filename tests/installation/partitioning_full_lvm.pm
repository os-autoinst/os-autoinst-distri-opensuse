# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Expert partitioner, full LVM encryption with MSDOS-MBR, without extra /boot https://fate.suse.com/320215
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub addlv {
    my ($name, $role, $size) = @_;
    my %lv_role = qw(
      OS alt-o
      data alt-d
      swap alt-s
      raw alt-a
    );
    send_key $cmd{addpart};
    send_key 'down';
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';    # create logical volume
    assert_screen 'partition-lv-type';
    type_string $name;
    send_key $cmd{next};
    assert_screen 'partition-lv-size';
    if ($size) {       # use default max size if not defined
        send_key 'alt-c';    # custom size
        type_string $size . 'GB';
    }
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key $lv_role{$role};    # swap role
    send_key $cmd{next};
    assert_screen 'partition-format';
    send_key $cmd{finish};
}

sub run() {
    send_key $cmd{expertpartitioner};
    for (1 .. 4) {
        send_key 'right';        # select vda hard disk
    }
    send_key 'alt-x';            # expert menu
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';              # create new partition table
    assert_screen 'partition-table-MSDOS-selected';
    send_key 'alt-o';            # OK
    assert_screen 'partition-create-new-table';
    send_key 'alt-y';            # yes
    send_key $cmd{addpart};
    assert_screen 'partition-type';
    send_key $cmd{next};
    assert_screen 'partition-size';
    send_key $cmd{next};
    assert_screen 'partition-role';
    send_key "alt-a";            # Raw Volume
    send_key $cmd{next};
    assert_screen 'partition-format';
    send_key $cmd{encrypt};
    assert_screen 'partition-lvm-encrypt';
    send_key $cmd{next};
    assert_screen 'partition-lvm-password-prompt';
    send_key 'alt-e';            # select password field
    type_password;
    send_key 'tab';
    type_password;
    send_key $cmd{finish};
    assert_screen 'expert-partitioner';
    send_key 'alt-s';            # select System view
    for (1 .. 2) {
        wait_screen_change { send_key 'down' };    # select Volume Management
    }
    send_key 'tab';                                # without this tab strange things will happen!
    send_key $cmd{addpart};                        # add
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';                                # create volume group
    assert_screen 'partition-add-volume-group';
    type_string 'vg-system';
    send_key 'alt-d';                              # add all
    wait_still_screen 2;
    save_screenshot;
    send_key $cmd{finish};
    addlv('lv-swap', 'swap', 2);
    assert_screen 'expert-partitioner';
    addlv('lv-root', 'OS');
    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    assert_screen 'partitioning-full-lvm-encrypt';
}

1;
# vim: set sw=4 et:
