# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Modify the RAID disk by removing the the swap in md1 from
# the default proposal and create swap in md0.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_module_consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Remove swap from md1
    assert_script_run 'swapoff /dev/md1p1 || true';
    assert_script_run 'sed -i "/\/dev\/md1p1/d" /etc/fstab';

    # Create a new partition on /dev/md0 (md0p2, e.g. 2GiB-4GiB for swap)
    assert_script_run 'parted /dev/md0 --script mkpart primary linux-swap 2GiB 100%';
    assert_script_run 'partprobe /dev/md0';

    # Create swap on md0
    assert_script_run 'mkswap /dev/md0p2';
    assert_script_run 'echo "/dev/md0p2 swap swap defaults 0 0" >> /etc/fstab';
    assert_script_run 'swapon /dev/md0p2';
}

1;
