# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper btrfsprogs
# Summary: Configure snapper and verify that timeline cleanup algorithm behaves accordingly.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use scheduler 'get_test_suite_data';
use filesystem_utils qw(get_partition_size get_used_partition_space);

sub pre_run_hook {
    my ($self) = @_;
    my $test_data = get_test_suite_data();
    select_console 'root-console';
    record_info("Configuration", "Configure snapper.");
    foreach my $param (keys %{$test_data->{snapper_config}}) {
        assert_script_run("snapper set-config $param=$test_data->{snapper_config}->{$param}",
            fail_message => "Snapper configuration failed for parameter $param");
    }
    $self->SUPER::pre_run_hook;
}

sub convert2numeric {
    my $str2convert = shift;
    my $convert_numeric = qr/[^0-9.]+/;
    $str2convert =~ s/$convert_numeric//;
    return $str2convert;
}

sub run {
    my $test_data = get_test_suite_data();
    record_info("Check quota", "Verify that the percentage of root filesystem quota is less than 50%");
    my $qgroup_space = script_output("btrfs qgroup show --sync --si / | grep \"1/0\" | awk \'{print \$3}\'");
    $qgroup_space = convert2numeric($qgroup_space);
    my $space_limit = $test_data->{snapper_config}->{SPACE_LIMIT};
    my $disk_size = convert2numeric(get_partition_size("/"));
    die "Snapshots take more than " . $space_limit * 100 . "% of root disk space"
      if ($qgroup_space >= $space_limit * $disk_size);

    # The cleanup timeline algorith will erase timeline snapshots if the free disk space is less than <FREE_LIMIT> %
    my $free_limit = $test_data->{snapper_config}->{FREE_LIMIT} * 100;
    record_info("Free > $free_limit%", "Ensure that free disk space is more than $free_limit%. 
	    Create a snapshot with timeline cleanup algorithm and make sure that it is not erased by the algorithm");
    my $used_disk = convert2numeric(get_used_partition_space("/"));
    die "Free disk space is less than $free_limit%" if ($used_disk > 100 - $free_limit);
    assert_script_run("snapper create --description \"timeline\" --cleanup-algorithm timeline",
        fail_message => "Timeline snapshot failed to be created");
    assert_script_run("snapper cleanup timeline",
        fail_message => "Timeline cleanup algorithm failed to run");
    assert_script_run("snapper ls | grep timeline",
        fail_message => "No timeline snapshot found");

    record_info("Free < $free_limit%", "Fill up disk space and make sure that the created snapshot gets erased by 
	    timeline cleanup algorithm");
    # Calculating the number of blocks that need to be written with random data, in order to
    # fill up the disk more than (100 - $free_limit)%. Due to rounding up of "df -h" command,
    # 10% is added to (100-FREE_LIMIT)% for safety reasons.
    # block number = (space to fill up)/(block size)=((100 - FREE_LIMIT - used_disk + 10)% * disk_size)/block_size
    # For the particular test, disk_size is in GB, we set block_size to 10M, so (% * GB)/10M = 1
    my $block_number = (100 - $free_limit - $used_disk + 10) * $disk_size;
    record_info("Fill up disk", "Filling up disk to " . (100 - $free_limit + 10) . "%");
    assert_script_run("dd status=progress if=/dev/urandom of=/tmp/blob bs=10M count=$block_number", timeout => 1500,
        fail_message => "Failed to fill up disk space");
    assert_script_run("sync", timeout => 60, fail_message => "Failed to sync");
    $used_disk = convert2numeric(get_used_partition_space("/"));
    die "Free disk space is more than $free_limit%" if ($used_disk <= 100 - $free_limit);
    assert_script_run("snapper cleanup timeline", fail_message => "Timeline cleanup algorithm failed to run");
    my $is_snapshot_erased = script_run "snapper ls | grep timeline";
    die "The cleanup algorithm didn't delete the snapshot as expected" unless $is_snapshot_erased;
}

1;
