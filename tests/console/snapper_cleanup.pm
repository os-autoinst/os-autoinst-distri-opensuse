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
use utils qw(service_action clear_console);

sub snapper_cleanup {
    my ($snapper)       = @_;
    my $snaps_numb      = "$snapper list | grep number | wc -l";
    my $btrfs_fs_usage  = "btrfs filesystem usage / --raw";
    my $fs_size         = script_output("$btrfs_fs_usage | sed -n '2p' | awk -F ' ' '{print\$3}'");
    my $used_space      = script_output("$btrfs_fs_usage | sed -n '6p' | awk -F ' ' '{print\$2}'");
    my $free_space      = script_output("$btrfs_fs_usage | sed -n '7p' | awk -F ' ' '{print\$3}'");
    my $excl_free_space = ($fs_size / 2);

    # we want to fill up disk enough so that snapper cleanup triggers
    my $scratch_size_gb = 6;
    my $fill_space      = 'dd if=/dev/urandom of=data bs=1M count=1024';
    my $snap_create     = "$snapper create --cleanup number --command '$fill_space'";
    assert_script_run "btrfs filesystem show --mbytes /";

    for (1 .. $scratch_size_gb / 2) { assert_script_run("$snap_create", 500); }

    script_run "echo There are `$snaps_numb` snapshots BEFORE cleanup";
    assert_script_run("$snapper cleanup number");    # cleanup created snapshots
    assert_script_run("btrfs quota rescan -w /", 15);
    script_run "echo There are `$snaps_numb` snapshots AFTER cleanup";
    assert_script_run("btrfs qgroup show -pcre /", 3);
    assert_script_run("$snapper list");
    clear_console;
    script_output("$btrfs_fs_usage | sed -n '7p' | awk -F ' ' '{print\$3}'");
    die "bsc#998360: Exclusive space is below user-defined limiti: $free_space (free_space) < $excl_free_space (excl_free_space)"
      if $free_space < $excl_free_space;
}

sub run() {
    select_console 'root-console';

    my @snapper_runs = 'snapper';
    push @snapper_runs, 'snapper --no-dbus' if get_var('SNAPPER_NODBUS');

    foreach my $snapper (@snapper_runs) {
        service_action('dbus', {type => ['socket', 'service'], action => ['stop', 'mask']}) if ($snapper =~ /dbus/);

        if (get_var("UPGRADE") || get_var("AUTOUPGRADE") && !get_var("BOOT_TO_SNAPSHOT")) {
            assert_script_run "$snapper setup-quota";
            assert_script_run "$snapper set-config NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10";
        }

        assert_script_run("$snapper get-config");    # get initial cfg
        assert_script_run("$snapper list");          # get initial list of snap's
        assert_script_run("$snapper set-config NUMBER_MIN_AGE=0");
        assert_script_run("btrfs qgroup show -pc /", 3);

        # We need to run snapper at least couple of times to ensure it cleans up properly
        # '4' is an arbitrary value proven by test
        for (1 .. 4) { snapper_cleanup($snapper); }

        assert_script_run("$snapper set-config NUMBER_MIN_AGE=1800");

        service_action('dbus', {type => ['socket', 'service'], action => ['unmask', 'start']}) if ($snapper =~ /dbus/);
    }
}

sub test_flags() {
    return {important => 1};
}

1;
