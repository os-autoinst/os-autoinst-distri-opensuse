# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: lvm2
# Summary: Simple LVM thin provisioning check
# Maintainer: Martin Loviska <mloviska@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my $lv_stats = {
        write_access => qr/\s{2}LV Write Access \s+ read\/write/,
        status => qr/\s{2}LV Status \s+ available/,
        readahead => qr/\s{2}Read ahead sectors \s+ auto/,
        # 254 as major no. points to dev-mapper, see /proc/devices
        block_device => qr/\s{2}Block device \s+ 254:\d/
    };

    select_serial_terminal;
    record_info('INFO', 'Print lvm setup');
    assert_script_run 'lsblk';
    assert_script_run 'lvmdiskscan';
    assert_script_run 'lvscan';
    assert_script_run 'lvs -a  | tee original_usage';
    assert_script_run 'pvs -a';
    # thin volume does not exceed thin pool size in our tests
    my @volumes = split(/\n/, script_output q[lvscan | awk '{print $2}'| sed s/\'//g]);
    # check for read only volumes and
    foreach my $volume (@volumes) {
        chomp;
        my $lvdisp_out = script_output "lvdisplay $volume";
        foreach (keys %{$lv_stats}) {
            die "Value of $lv_stats->{$_} was not found in $volume configuration" unless ($lvdisp_out =~ /(?<tested_string>$lv_stats->{$_})/);
            record_info('TEST', "Found $+{tested_string} in $volume");
        }
    }

    record_info('INFO', 'Create a file on thin volume');
    my $test_file = '/home/bernhard/test_file.txt';
    assert_script_run "dd if=/dev/zero of=$test_file count=1024 bs=1M";
    assert_script_run "ls -lah $test_file";
    assert_script_run 'lvs -a | tee instant_usage';
    if ((script_run 'diff original_usage instant_usage') != 1) {
        die "LVM usage stats do not differ!";
    }
}

1;

