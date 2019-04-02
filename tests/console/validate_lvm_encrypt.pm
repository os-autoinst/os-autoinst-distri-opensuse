# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Simple LVM partition validation
# Maintainer: Yiannis Bonatakis <ybonatakis@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use y2logsstep;
use Test::Assert ':all';
use version_utils qw(is_aarch64 is_storage_ng);


sub run {
    my $self              = shift;
    my $expected_lv_stats = {
        write_access => qr/\s{2}LV Write Access \s+ read\/write/,
        status       => qr/\s{2}LV Status \s+ available/,
        readahead    => qr/\s{2}Read ahead sectors \s+ auto/,
        testactive   => qr/\s{2}# open \s+ [12]/,
        # 254 as major no. points to dev-mapper, see /proc/devices
        block_device => qr/\s{2}Block device \s+ 254:\d/
    };

    $self->select_serial_terminal;

    record_info('INFO', 'Validate LVM config');
    assert_script_run "lvmconfig --mergedconfig --validate | grep \"LVM configuration valid.\"";

    record_info('INFO', 'Find encrypted volumes');
    my $encrypted_partition = script_output q[cat /etc/crypttab | awk '{print $1}'];
    assert_script_run qq[cryptsetup status /dev/mapper/$encrypted_partition | grep "is active"];

    record_info('INFO', 'Validate setup');
    assert_script_run 'lvmdiskscan -v';
    my @active_vols = split(/\n/, script_output q[lvscan | awk '{print $1}']);
    foreach my $vol_status (@active_vols) {
        assert_equals($vol_status, 'ACTIVE', "Volume is Inactive");
    }

    my $pvTotalPE = script_output q[pvdisplay|grep "Total PE" | awk '{print $3}'];
    my $pvFreePE  = script_output q[pvdisplay|grep "Free PE" | awk '{print $3}'];
    my $pe_size   = $pvTotalPE - $pvFreePE;

    assert_script_run 'pvs -a';

    my @volumes = split(/\n/, script_output q[lvscan | awk '{print $2}'| sed s/\'//g]);
    my $lv_size = 0;

    foreach my $volume (@volumes) {
        chomp;
        my $lvdisp_output = script_output "lvdisplay $volume";
        my $val           = script_output qq[lvdisplay $volume|grep \"Current LE\" | awk '{print \$3}'];

        $lv_size += script_output qq[lvdisplay $volume|grep \"Current LE\" | awk '{print \$3}'];

        my $results = '';
        foreach (keys %{$expected_lv_stats}) {
            $results .= "$_ was not found in filesystem\n" unless ($lvdisp_output =~ /(?<tested_string>$expected_lv_stats->{$_})/);
            record_info('TEST', "Found $+{tested_string} in $volume");
        }
        die "Partitions not found in $volume configuration: \n $results" if ($results);
    }

    assert_equals($pe_size, $lv_size, "Sum of Logical Extends differs!");

    record_info('INFO', 'Create a file on home volume');
    my $test_file = '/home/bernhard/test_file.txt';
    assert_script_run 'df -h  | tee original_usage';
    assert_script_run "dd if=/dev/zero of=$test_file count=1024 bs=1M";
    assert_script_run "ls -lah $test_file";
    if ((script_run "sync && diff <(cat original_usage) <(df -h)") != 1) {
        die "LVM usage stats do not differ!";
    }

    record_info('INFO', 'Check partitions');
    if ((get_var('NAME') =~ m/separate/) || is_aarch64 && !is_storage_ng) {    # Separate boot partition, not encrypted. aarch64+!storage_ng: see poo#49718
        assert_script_run q[df | grep -P "^\/dev\/.{3}\d{1}"| grep boot];
    }
    else {                                                                     # Encrypted boot partition with lvm
        assert_script_run q[df | grep -P "^\/dev/\mapper\/\w+"| grep boot];
    }
}

1;

