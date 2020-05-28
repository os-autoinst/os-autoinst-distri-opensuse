# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure snapper and verify that timeline cleanup algorithm behaves accordingly.
# Maintainer: QA SLE YaST team <qa-sle-yast@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use scheduler 'get_test_suite_data';
use Test::Assert ':all';

sub pre_run_hook {
    my $test_data = get_test_suite_data();
    select_console 'root-console';
    record_info("Configuration", "Configure snapper.");
    foreach my $param (keys %{$test_data->{snapper_config}}) {
        assert_script_run("snapper set-config $param=$test_data->{snapper_config}->{$param}",
            fail_message => "Snapper configuration failed for parameter $param");
    }
}

sub convert2numeric {
    my $str2convert     = shift;
    my $convert_numeric = qr/[^0-9.]+/;
    $str2convert =~ s/$convert_numeric//;
    return $str2convert;
}

sub get_used_disk_space {
    my $used_space = script_output("df -h /  | awk \'NR==2 {print \$5}\'");
    return convert2numeric($used_space);
}

sub run {
    my $test_data = get_test_suite_data();
    record_info("Check quota", "Verify that the percentage of root filesystem quota is less than 50%");
    my $qgroup_space = script_output("btrfs qgroup show --sync --si / | grep \"1/0\" | awk \'{print \$3}\'");
    $qgroup_space = convert2numeric($qgroup_space);
    my $space_limit = $test_data->{snapper_config}->{SPACE_LIMIT};
    my $disk_size   = script_output("df -h /  | awk \'NR==2 {print \$2}\'");
    $disk_size = convert2numeric($disk_size);
    die "Snapshots take more than " . $space_limit * 100 . "% of root disk space"
      if ($qgroup_space >= $space_limit * $disk_size);

    my $free_limit = $test_data->{snapper_config}->{FREE_LIMIT} * 100;
    record_info("Space > $free_limit%", "Ensure that free space is more than $free_limit%. 
	    Create a snapshot with timeline cleanup algorithm and make sure that it is not erased by the algorithm");
    die "Free disk space is less than $free_limit%" if (get_used_disk_space() > 100 - $free_limit);
    assert_script_run("snapper create --description \"timeline\" --cleanup-algorithm timeline",
        fail_message => "Timeline snapshot failed to be created");
    assert_script_run("snapper cleanup timeline",
        fail_message => "Timeline cleanup algorithm failed to run");
    assert_script_run("snapper ls | grep timeline",
        fail_message => "No timeline snapshot found");

    record_info("Space < $free_limit%", "Fill up disk space and make sure that the created snapshot gets erased by 
	    timeline cleanup algorithm");
    assert_script_run("dd if=/dev/urandom of=/tmp/blob bs=10M count=3080", timeout => 900,
        fail_message => "Failed to fill up disk space");
    die "Free disk space is more than $free_limit%" if (get_used_disk_space() <= 100 - $free_limit);
    assert_script_run("snapper cleanup timeline", fail_message => "Timeline cleanup algorithm failed to run");
    my $is_snapshot_erased = script_run "snapper ls | grep timeline";
    die "The cleanup algorithm didn't delete the snapshot as expected" unless $is_snapshot_erased;
}

1;
