# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Warning for migrations with low disk space
#
#    If variable UPGRADE=LOW_SPACE is present allocate most of the disk
#    space before installation. Warning should be visible in installation
#    overview.
#
#    Then parse required size from warning message and free disk space
#    accordingly. Refresh overview screen and if warning message disappear
#    start installation.
# Maintainer: mkravec <mkravec@suse.com>

use base 'y2_installbase';
use testapi;

# poo#11438
sub run {
    # After mounting partitions leave only 100M available
    select_console('install-shell');
    my $avail = script_output "btrfs fi usage -m /mnt | awk '/Free/ {print \$3}' | cut -d'.' -f 1";
    assert_script_run "fallocate -l " . ($avail - 100) . "m /mnt/FILL_DISK_SPACE";
    select_console('installation');
}

1;
