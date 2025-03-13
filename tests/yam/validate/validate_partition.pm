# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Validate the partition with lsblk
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Test::Assert ':assert';

sub run {
    select_console 'root-console';
    record_info('Disk partition', script_output("lsblk --output KNAME,FSTYPE,TRAN,LABEL,MOUNTPOINTS", proceed_on_failure => 1));
    record_info('Disk partition', script_output("lsblk -o KNAME,MOUNTPOINT,SIZE,RO,TYPE,VENDOR,TRAN,MODE,HCTL,STATE,MAJ:MIN", proceed_on_failure => 1));
    record_info('Disk partition', script_output("df -h", proceed_on_failure => 1));
    record_info('lsblk', script_output("lsblk", proceed_on_failure => 1));
    # assert_equals($expected_prod, $prod, "Wrong product name in '/etc/products.d/baseproduct'");
}

1;
