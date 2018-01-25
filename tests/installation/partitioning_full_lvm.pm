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
use partition_setup;
use version_utils 'is_storage_ng';

sub run {
    create_new_partition_table;
    if (check_var('ARCH', 's390x')) {    # s390x need /boot/zipl on ext partition
        addpart(role => 'OS', size => 500, format => 'ext2', mount => '/boot');
    }
    elsif (check_var('ARCH', 'ppc64le')) {    # ppc64le need PReP /boot
        addpart(role => 'raw', size => 500, fsid => 'PReP');
    }
    elsif (is_storage_ng) {
        # Storage-ng has GPT by defaut, so need bios-boot partition
        addpart(role => 'raw', fsid => 'bios-boot', size => 1);
    }
    addpart(role => 'raw', encrypt => 1);
    assert_screen 'expert-partitioner';
    send_key 'alt-s';                         # select System view
    send_key_until_needlematch('volume_management_feature', 'down');    # select Volume Management
    send_key $cmd{addpart};                                             # add
    wait_still_screen 2;
    save_screenshot;
    send_key 'down';
    send_key 'ret';                                                     # create volume group
    assert_screen 'partition-add-volume-group';
    send_key 'alt-v';                                                   # volume group name
    type_string 'vg-system';
    send_key 'alt-d';                                                   # add all
    wait_still_screen 2;
    save_screenshot;
    send_key(is_storage_ng() ? $cmd{next} : $cmd{finish});
    addlv(name => 'lv-swap', role => 'swap', size => 2000);
    assert_screen 'expert-partitioner';

    if (is_storage_ng) {
        # Mount point is not preselected for OS role in storage-ng
        record_soft_failure("bsc#1073854");
        addlv(name => 'lv-root', role => 'OS', mount => '/');
    }
    else {
        addlv(name => 'lv-root', role => 'OS');
    }
    assert_screen 'expert-partitioner';
    send_key $cmd{accept};
    assert_screen 'partitioning-full-lvm-encrypt';
}

1;
# vim: set sw=4 et:
