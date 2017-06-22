# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Snapper cleanup test based on FATE#312751
# Maintainer: Dumitru Gutu <dgutu@suse.com>

use base "consoletest";
use strict;
use testapi;
use utils 'clear_console';

sub snapper_cleanup {
    my $snaps_numb      = "snapper list | grep number | wc -l";
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

    for (1 .. $scratch_size_gb / 2) { assert_script_run("$snap_create", 500); }

    script_run "echo There are `$snaps_numb` snapshots BEFORE cleanup";
    assert_script_run("snapper cleanup number",  180);    # cleanup created snapshots
    assert_script_run("btrfs quota rescan -w /", 15);
    script_run "echo There are `$snaps_numb` snapshots AFTER cleanup";
    assert_script_run("btrfs qgroup show -pcre /", 3);
    assert_script_run("snapper list");
    clear_console;
    script_output("$btrfs_fs_usage | sed -n '7p' | awk -F ' ' '{print\$3}'");

    if ($free_space < $excl_free_space) {
        my $msg = "bsc#998360: Exclusive space is below user-defined limit: $free_space (free_space) < $excl_free_space (excl_free_space)";
        if (check_var('VERSION', '12-SP2')) {
            record_soft_failure $msg;
        }
        else {
            die $msg;
        }
    }
}

sub run {
    select_console 'root-console';

    if (get_var("UPGRADE") || get_var("AUTOUPGRADE") && !get_var("BOOT_TO_SNAPSHOT")) {
        assert_script_run "snapper setup-quota";
        assert_script_run "snapper set-config NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10";
    }

    assert_script_run("snapper get-config");    # get initial cfg
    assert_script_run("snapper list");          # get initial list of snap's
    assert_script_run("snapper set-config NUMBER_MIN_AGE=0");
    assert_script_run("btrfs qgroup show -pc /", 3);

    # We need to run snapper at least couple of times to ensure it cleans up properly
    # '4' is an arbitrary value proven by test
    for (1 .. 4) { snapper_cleanup; }

    assert_script_run("snapper set-config NUMBER_MIN_AGE=1800");
}


sub post_fail_hook {
    my ($self) = @_;
    upload_logs('/var/log/snapper.log');
}

1;

# vim: set sw=4 et:
