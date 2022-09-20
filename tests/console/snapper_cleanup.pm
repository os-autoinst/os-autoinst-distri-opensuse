# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper btrfsprogs
# Summary: Snapper cleanup test based on FATE#312751
# - In case of upgrade or BOOT_TO_SNAPSHOT not set
#   - Run snapper setup-quota
#   - snapper set-config NUMBER_LIMIT_IMPORTANT=4-10 SPACE_LIMIT=0.5
# - Get initial cfg and save initial NUMBER_LIMIT and NUMBER_MIN_AGE settings for later restore
# - Check amount of free fs disk space and adapt to it
# - Set NUMBER_LIMIT such that disk space after cleanup
# - Exclusive disk space of qgroup should be ~50% of the fs space as set with
#   SPACE_LIMIT
# - Run snapper at least couple of times to ensure it cleans up properly
# - Cleanup
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use utils 'clear_console';
use List::Util qw(max min);
use version_utils qw(is_sle);

my $exp_excl_space;
my $btrfs_fs_usage = 'btrfs filesystem usage / --raw';

sub get_space {
    my ($script) = @_;
    my $script_output = script_output($script, timeout => 120);
    return $script_output;
}

sub snapper_cleanup {
    my ($scratch_size_gb, $scratchfile_mb) = @_;
    my $snaps_numb = "snapper list | grep number | wc -l";

    script_run($btrfs_fs_usage, 120);
    # we want to fill up disk enough so that snapper cleanup triggers
    my $fill_space = "dd if=/dev/urandom of=data bs=1M count=$scratchfile_mb";
    my $snap_create = "snapper create --cleanup number --command '$fill_space'";
    assert_script_run "btrfs filesystem show --mbytes /";

    for (1 .. $scratch_size_gb) { assert_script_run("$snap_create", 500); }
    assert_script_run('sync');
    script_run "echo There are `$snaps_numb` snapshots BEFORE cleanup";
    assert_script_run("snapper cleanup number", 300);    # cleanup created snapshots
    assert_script_run("btrfs quota rescan -w /", 90);
    script_run "echo There are `$snaps_numb` snapshots AFTER cleanup";
    assert_script_run("btrfs qgroup show -pcre /");
    assert_script_run("snapper list");
    clear_console unless testapi::is_serial_terminal();
    script_run($btrfs_fs_usage, 120);
    # Get actual exclusive disk space to verify exclusive disk space is taken into account
    my $qgroup_excl_space = get_space("btrfs qgroup show  / --raw | grep 1/0 | awk -F ' ' '{print\$3}'");
    if ($qgroup_excl_space > $exp_excl_space) {
        my $msg = "bsc#998360: qgroup 1/0: Exclusive space is above user-defined limit:\n"
          . "$exp_excl_space (expected exclusive disk space) < $qgroup_excl_space (consumed exclusive disk space)";
        if (check_var('VERSION', '12-SP2')) {
            record_info $msg, result => 'softfail';
        }
        else {
            die $msg;
        }
    }
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;
    $self->cron_mock_lastrun() if is_sle('<15');

    if (get_var("UPGRADE") || get_var("AUTOUPGRADE") && !get_var("BOOT_TO_SNAPSHOT")) {
        assert_script_run "snapper setup-quota";
        # Note: Later, NUMBER_LIMIT will be customized (unconditionally), too
        assert_script_run "snapper set-config NUMBER_LIMIT_IMPORTANT=4-10 SPACE_LIMIT=0.5";
    }

    my ($n_scratch_prepost, $scratchfile_mb, $safety_margin_mb, $initially_free);
    my ($nmax_snapshots, $number_limit_upper, $number_limit_upper_max, $n);
    my ($number_limit_pre, $number_min_age_pre);

    # test parameters; hardcoded values found appropriate in past tests
    $n_scratch_prepost = 3;
    $scratchfile_mb = 1024;
    # Keep the test from filling the last 300 MB of the filesystem, poo#36838
    # Takes into account that scratch file "data" is not yet present at the beginning
    $safety_margin_mb = 300 + $scratchfile_mb;
    # Never keep more snapshots than this after cleanup: it would only consume
    # runtime without adding substance. 18 seems a reasonable empirical limit.
    $number_limit_upper_max = 18;

    # get initial cfg and save initial NUMBER_LIMIT and NUMBER_MIN_AGE settings for later restore
    assert_script_run("snapper get-config");
    foreach (split /\n/, script_output("snapper get-config")) {
        $number_limit_pre = $1 if (m/^NUMBER_LIMIT\s+\|\s+([-\d]+)\s*$/);
        $number_min_age_pre = $1 if (m/^NUMBER_MIN_AGE\s+\|\s+(\d+)\s*$/);
    }
    assert_script_run("snapper list");    # get initial list of snap's

    # check amount of free fs disk space and adapt to it
    # This test creates pre/post snapshot pairs each of which costs about $scratchfile_mb MiB
    # Disk space thus dictates: number of present test snapshots must never exceed $nmax_snapshots
    $initially_free = get_space("$btrfs_fs_usage | awk -F ' ' '/Free .estimated.:.*min:/{print\$3}'");    # bytes
    $nmax_snapshots = int(($initially_free / (1024 * 1024) - $safety_margin_mb) / $scratchfile_mb) * 2;

    # NUMBER_LIMIT setting such that disk space after cleanup
    # allows another $n_scratch_prepost pre/post snapshot pairs
    $number_limit_upper = $nmax_snapshots - $n_scratch_prepost * 2;
    if ($number_limit_upper > 0) {
        # plenty of free space? No ambition to fill it all, then.
        $number_limit_upper = min($number_limit_upper, $number_limit_upper_max);
        assert_script_run "snapper set-config NUMBER_LIMIT=2-$number_limit_upper NUMBER_MIN_AGE=0";
    }
    elsif ($number_limit_upper == 0) {
        assert_script_run "snapper set-config NUMBER_LIMIT=0 NUMBER_MIN_AGE=0";
    }
    else {
        die("Insufficient initial disk space left on / to run this test: $initially_free bytes");
    }
    assert_script_run("snapper get-config");    # report customized cfg
    assert_script_run("btrfs qgroup show -pc /");
    # Exclusive disk space of qgroup should be ~50% of the fs space as set with SPACE_LIMIT
    $exp_excl_space = get_space("$btrfs_fs_usage | sed -n '2p' | awk -F ' ' '{print\$3}'") / 2;
    # We need to run snapper at least couple of times to ensure it cleans up properly
    # Specifically: let Iteration $n - 3 be the last to not yet be forced by the
    # NUMBER_LIMIT setting alone to actually carry out clean-ups
    $n = $number_limit_upper / ($n_scratch_prepost * 2) + 3;

    for (1 .. $n) { snapper_cleanup($n_scratch_prepost, $scratchfile_mb); }

    # tidy up and restore default settings
    assert_script_run("snapper set-config NUMBER_LIMIT=0; snapper cleanup number; rm -fv data", 300);
    assert_script_run("snapper set-config NUMBER_LIMIT=$number_limit_pre NUMBER_MIN_AGE=$number_min_age_pre");
    assert_script_run("snapper get-config; snapper ls");    # final report
    assert_script_run("$btrfs_fs_usage", 120);    # final report
}

1;

