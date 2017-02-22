# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Expert partitioner, full LVM encryption with MSDOS-MBR, without extra /boot on x86_64 arch https://fate.suse.com/320215
#          on s390x and ppc64le with extra /boot, not on aarch64 because of UEFI
# Maintainer: Jozef Pupava <jpupava@suse.com>

use strict;
use warnings;
use base 'y2logsstep';
use testapi;

my %role = qw(
  OS alt-o
  data alt-d
  swap alt-s
  raw alt-a
);

sub addpart {
    my (%args) = @_;
    assert_screen 'expert-partitioner';
    send_key $cmd{addpart};
    if (!get_var('UEFI')) {    # partitioning type does not appear when GPT disk used, GPT is default for UEFI
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

sub run() {
    send_key $cmd{expertpartitioner};
    assert_screen 'expert-partitioner';
    wait_still_screen;
    for (1 .. 4) {
        send_key 'right';           # select vda hard disk
    }
    send_key 'alt-x';               # expert menu
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';                 # create new partition table
    if (!get_var('UEFI')) {         # only GPT partition table
        assert_screen 'partition-table-MSDOS-selected';
        send_key 'alt-o';           # OK
    }
    assert_screen 'partition-create-new-table';
    send_key 'alt-y';               # yes
    if (check_var('ARCH', 's390x')) {    # s390x need /boot/zipl on ext partition
        addpart(role => 'OS', size => 500, format => 'ext2', mount => '/boot');
    }
    elsif (check_var('ARCH', 'ppc64le')) {    # ppc64le need PReP /boot
        addpart(role => 'raw', size => 500, fsid => 'PReP');
    }
    addpart(role => 'raw', encrypt => 1);
    assert_screen 'expert-partitioner';
    send_key 'alt-s';                         # select System view
    for (1 .. 2) {
        send_key 'down';                      # select Volume Management
    }
    send_key $cmd{addpart};                   # add
    send_key 'down';
    wait_still_screen 2;
    save_screenshot;
    send_key 'ret';                           # create volume group
    assert_screen 'partition-add-volume-group';
    type_string 'vg-system';
    send_key 'alt-d';                         # add all
    wait_still_screen 2;
    save_screenshot;
    send_key $cmd{finish};
    addlv(name => 'lv-swap', role => 'swap', size => 2000);
    assert_screen 'expert-partitioner';
    addlv(name => 'lv-root', role => 'OS');
    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    assert_screen 'partitioning-full-lvm-encrypt';
}

1;
# vim: set sw=4 et:
