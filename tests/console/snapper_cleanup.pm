# SUSE's openQA tests
#
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Snapper cleanup test based on FATE#312751
# Maintainer: Rodion Iafarov <riafarov@suse.com>

use base 'btrfs_test';
use strict;
use testapi;
use utils 'clear_console';
use List::Util 'max';

my $exp_excl_space;
my $btrfs_fs_usage = 'btrfs filesystem usage / --raw';

sub get_space {
    my ($script) = @_;
    my $script_output = script_output($script);
    # Problem is that sometimes we get kernel messages or other output when execute the script
    # So we assume that biggest number returned is size we are looking for
    if ($script_output =~ /^(\d+)$/) {
        return $script_output;
    }
    record_soft_failure('bsc#1011815');
    my @numbers = $script_output =~ /(\d+)/g;

    return max(@numbers);
}
sub snapper_cleanup {
    my $snaps_numb = "snapper list | grep number | wc -l";

    script_run($btrfs_fs_usage);
    # we want to fill up disk enough so that snapper cleanup triggers
    my $scratch_size_gb = 3;
    my $fill_space      = 'dd if=/dev/urandom of=data bs=1M count=1024';
    my $snap_create     = "snapper create --cleanup number --command '$fill_space'";
    assert_script_run "btrfs filesystem show --mbytes /";

    for (1 .. $scratch_size_gb) { assert_script_run("$snap_create", 500); }
    script_run "echo There are `$snaps_numb` snapshots BEFORE cleanup";
    assert_script_run("snapper cleanup number",  180);    # cleanup created snapshots
    assert_script_run("btrfs quota rescan -w /", 15);
    script_run "echo There are `$snaps_numb` snapshots AFTER cleanup";
    assert_script_run("btrfs qgroup show -pcre /", 3);
    assert_script_run("snapper list");
    clear_console;
    script_run($btrfs_fs_usage);
    # Get actual exckusive disk space to verify exclusive disk space is taken into account
    my $qgroup_excl_space = get_space("btrfs qgroup show  / --raw | grep 1/0 | awk -F ' ' '{print\$3}'");
    if ($qgroup_excl_space > $exp_excl_space) {
        my $msg = "bsc#998360: Exclusive space is above user-defined limit: "
          . "$exp_excl_space (expected exclusive disk space) < $qgroup_excl_space (expected exclusive disk space)";
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
        assert_script_run "snapper set-config NUMBER_LIMIT=2-10 NUMBER_LIMIT_IMPORTANT=4-10 SPACE_LIMIT=0.5";
    }

    assert_script_run("snapper get-config");    # get initial cfg
    assert_script_run("snapper list");          # get initial list of snap's
    assert_script_run("snapper set-config NUMBER_MIN_AGE=0");
    assert_script_run("btrfs qgroup show -pc /", 3);
    # Exclusive disk space of qgroup should be ~50% of the fs space as set with SPACE_LIMIT
    $exp_excl_space = get_space("$btrfs_fs_usage | sed -n '2p' | awk -F ' ' '{print\$3}'") / 2;
    # We need to run snapper at least couple of times to ensure it cleans up properly
    # '4' is an arbitrary value proven by test
    for (1 .. 4) { snapper_cleanup; }

    assert_script_run("snapper set-config NUMBER_MIN_AGE=1800");
}

1;

# vim: set sw=4 et:
