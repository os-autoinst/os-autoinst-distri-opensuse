# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Expert partitioner, full LVM encryption with MSDOS-MBR, without extra /boot on x86_64 arch https://fate.suse.com/320215
#          on s390x and ppc64le with extra /boot, not on aarch64 because of UEFI
#          Requirements are different for storage-ng https://github.com/yast/yast-storage-ng/blob/master/doc/boot-requirements.md
#          With UNENCRYPTED_BOOT set to true, test will have separate /boot partition for all architectures
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use partition_setup qw(create_new_partition_table addboot addpart addvg addlv);
use version_utils 'is_storage_ng';

sub run {
    create_new_partition_table;
    addboot;
    addpart(role => 'raw', encrypt => 1);
    addvg(name => 'vg-system', add_all_pvs => 1);
    addlv(name => 'lv-swap', role => 'swap', vg => 'vg-system', size => 2000);
    addlv(name => 'lv-root', role => 'OS', vg => 'vg-system');
    # move to layout overview
    send_key $cmd{accept};
    if (get_var('UNENCRYPTED_BOOT')) {
        assert_screen 'partitioning-full-lvm-encrypt-unencrypted-boot';
    }
    else {
        assert_screen 'partitioning-full-lvm-encrypt';
    }
}

1;
