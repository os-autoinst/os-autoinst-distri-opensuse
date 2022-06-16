# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Simple LVM partition validation
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use Test::Assert ':all';
use Mojo::JSON 'decode_json';
use List::Util 'sum';

sub pre_run_hook {
    my ($self) = @_;
    select_console('root-console');
    $self->SUPER::pre_run_hook;
}

sub run {
    record_info('LVM config', 'Validate LVM config');
    assert_script_run('lvmconfig --mergedconfig --validate | grep "LVM configuration valid."',
        fail_message => 'LVM config validation failed');

    record_info('LVM volume', 'Verify the LVM physical volume(s) exists');
    assert_script_run('lvmdiskscan -v | egrep "LVM physical volume?$"',
        fail_message => 'LVM physical volume does not exist.');

    record_info('ACTIVE volumes', 'Verify all Logical Volumes are ACTIVE');
    my @active_vols = split(/\n/, script_output q[lvscan | awk '{print $1}']);
    foreach my $vol_status (@active_vols) {
        assert_equals($vol_status, 'ACTIVE', "Volume is Inactive");
    }

    # Sum up the Physical Extents across all Physical Volumes within each Volume group
    # Then so we can compare total PEs with total logical extents.
    record_info('equal extents', 'Verify sum of logical extents corresponds to physical extent size');
    my @pvdisplay_output = split(/\n/, script_output q[pvdisplay]);
    my (@PE, @free_PE);
    foreach (@pvdisplay_output) {
        if ($_ =~ /.*Total PE\s*(?<total_pe>\S*)$/) {
            push(@PE, $+{total_pe});
        }
        if ($_ =~ /.*Free PE\s*(?<total__free_pe>\S*)$/) {
            push(@free_PE, $+{total_free_pe});
        }
    }
    my $total_PEs = sum(@PE);
    my $total_free_PEs = sum(@free_PE);
    my @volumes = split(/\n/, script_output q[lvscan | awk '{print $2}'| sed s/\'//g]);
    my $lv_size = 0;

    foreach my $volume (@volumes) {
        chomp;
        my $lvdisp_output = script_output "lvdisplay $volume";
        $lv_size += script_output qq[lvdisplay $volume|grep \"Current LE\" | awk '{print \$3}'];

        my $results = '';
        my $expected_lv_stats = {
            write_access => qr/\s{2}LV Write Access \s+ read\/write/,
            status => qr/\s{2}LV Status \s+ available/,
            readahead => qr/\s{2}Read ahead sectors \s+ auto/,
            testactive => qr/\s{2}# open \s+ [12]/,
            # 254 as major no. points to dev-mapper, see /proc/devices
            block_device => qr/\s{2}Block device \s+ 254:\d/
        };
        foreach (keys %{$expected_lv_stats}) {
            $results .= "$_ was not found in filesystem\n" unless ($lvdisp_output =~ /(?<tested_string>$expected_lv_stats->{$_})/);
            diag("Found $+{tested_string} in $volume");
        }
        die "Partitions not found in $volume configuration: \n $results" if ($results);
    }
    assert_equals($total_PEs - $total_free_PEs, $lv_size, "Sum of Logical Extents differs!");
    record_info('LVM usage stats', 'Verify LVM usage stats are updated after adding a file.');
    my $test_file = '/home/test_file.txt';
    assert_script_run 'df -h  | tee original_usage';
    assert_script_run "fallocate -l 1G $test_file";
    assert_script_run "ls -lah $test_file";
    if ((script_run "sync && diff <(cat original_usage) <(df -h)") != 1) {
        die "LVM usage stats do not differ!";
    }

    unless (get_var('MULTIPATH')) {
        record_info('parted align', 'Verify if partition satisfies the alignment constraint of optimal type');
        my $lsblk_output_json = script_output qq[lsblk -p -o NAME,TYPE,MOUNTPOINT -J -e 11];
        my $drives = extract_drives_from_json($lsblk_output_json);
        my $i;
        foreach my $dev (@{$drives}) {
            $i = 1;
            foreach my $child (@{get_children($dev)}) {
                assert_script_run("parted -s $dev->{name} align-check optimal $i");
                $i++;
            }
        }
    }
}

# pass all block devices from json lsblk output
sub extract_drives_from_json {
    my $lsblk_json = shift;
    diag("Extract drives from JSON:\n$lsblk_json");
    my $decoded_json = decode_json($lsblk_json);
    (ref($decoded_json) eq 'HASH' and ref($decoded_json->{blockdevices}) eq 'ARRAY') ?
      return $decoded_json->{blockdevices} : die "Block devices not found among json data";
}

sub get_children {
    my $drive = shift;
    return (
        (ref($drive) eq 'HASH') and
          defined($drive->{children})) ? $drive->{children} : [];
}

1;

