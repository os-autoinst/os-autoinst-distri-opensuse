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
use strict;
use warnings;
use testapi;

# poo#11438
sub run {
    # Release disk space according to warning message + some extra
    assert_screen "low-space-warning";
    select_console('install-shell');
    my $required = script_output 'grep -Eo "needs [0-9]+\.?[0-9]* [MG]iB more disk space." /var/log/YaST2/y2log | tail -1';
    if ($required =~ /([0-9]+\.?[0-9]*) ([MG])iB/) {
        my ($req_size, $req_unit) = ($1, $2);
        if ($req_unit eq 'M') { }
        elsif ($req_unit eq 'G') { $req_size *= 1024 }
        else { die "Unexpected value of req_unit: $req_unit" }

        assert_script_run "rm /mnt/FILL_DISK_SPACE";
        assert_script_run "btrfs fi sync /mnt";

        my $avail = script_output "btrfs fi usage -m /mnt | awk '/Free/ {print \$3}' | cut -d'.' -f 1";
        assert_script_run "fallocate -l " . int($avail - $req_size - 300) . "m /mnt/FILL_DISK_SPACE";
        assert_script_run "btrfs fi sync /mnt";
    }
    else {
        die "Unable to parse requiered values from y2log.";
    }
    select_console('installation');
    send_key "alt-b";
    wait_still_screen;
    send_key_until_needlematch "inst-overview", "alt-n", 4, 30;
    assert_screen "no-packages-warning";
}

1;
