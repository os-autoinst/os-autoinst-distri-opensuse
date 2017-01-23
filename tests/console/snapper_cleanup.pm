# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Snapper cleanup test based on FATE#312751
# G-Maintainer: Dumitru Gutu <dgutu@suse.com>

use base "consoletest";
use strict;
use utils;
use testapi;

sub snapper_cleanup() {
    my $snaps_numb      = "snapper ls | grep number | wc -l";
    my $btrfs_fs_usage  = "btrfs filesystem usage / --raw";
    my $fs_size         = script_output("$btrfs_fs_usage | sed -n '2p' | awk -F ' ' '{print\$3}'");
    my $used_space      = script_output("$btrfs_fs_usage | sed -n '6p' | awk -F ' ' '{print\$2}'");
    my $free_space      = script_output("$btrfs_fs_usage | sed -n '7p' | awk -F ' ' '{print\$3}'");
    my $excl_free_space = ($fs_size / 2);

    # we want to fill up disk enough so that snapper cleanup triggers
    my $scratch_size_gb = 6;
    my $fill_space      = 'dd if=/dev/urandom of=data bs=1M count=1024';
    my $snap_create     = "snapper create --cleanup number --command '$fill_space'";
    assert_script_run "btrfs filesystem show --mbytes /";

    for (1 .. $scratch_size_gb / 2) {
        assert_script_run("$snap_create", 500);
    }

    script_run "echo There are `$snaps_numb` snapshots BEFORE cleanup";
    assert_script_run("snapper cleanup number");    # cleanup created snapshots
    assert_script_run("btrfs quota rescan -w /", 15);
    script_run "echo There are `$snaps_numb` snapshots AFTER cleanup";
    assert_script_run("btrfs qgroup show -pcre /", 3);
    script_run("snapper ls");
    clear_console;
    script_output("$btrfs_fs_usage | sed -n '7p' | awk -F ' ' '{print\$3}'");
    die "Exclusive space is below user-defined limit - bsc#998360" unless $free_space > $excl_free_space;
}

sub run() {

    select_console 'root-console';

    script_run("snapper get-config");    # get initial cfg
    script_run("snapper ls");            # get initial list of snap's
    if (sle_version_at_least('12-SP3')) { script_run("btrfs quota enable /"); }

    if (get_var("UPGRADE") || get_var("AUTOUPGRADE") && !get_var("BOOT_TO_SNAPSHOT")) {
        assert_script_run("snapper setup-quota");
        assert_script_run("snapper set-config NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10");
    }

    assert_script_run("snapper set-config NUMBER_MIN_AGE=0");
    assert_script_run("btrfs qgroup show -pc /", 3);

    # we need to run snapper at least some times to ensure it cleans up properly
    # arbitrary value proven by test
    my $snapper_runs = 4;

    for (1 .. $snapper_runs) { snapper_cleanup() }

    assert_script_run("snapper set-config NUMBER_MIN_AGE=1800");
}

sub test_flags() {
    return {important => 1};
}

1;
