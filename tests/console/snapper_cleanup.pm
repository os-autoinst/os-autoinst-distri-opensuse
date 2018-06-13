# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
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
    my ($scratch_size_gb,$scratchfile_mb) = @_;
    my $snaps_numb = "snapper list | grep number | wc -l";

    script_run($btrfs_fs_usage);
    # we want to fill up disk enough so that snapper cleanup triggers
    my $fill_space      = "dd if=/dev/urandom of=data bs=1M count=$scratchfile_mb";
    my $snap_create     = "snapper create --cleanup number --command '$fill_space'";
    assert_script_run "btrfs filesystem show --mbytes /";

    for (1 .. $scratch_size_gb) { assert_script_run("$snap_create", 500); }
    script_run "echo There are `$snaps_numb` snapshots BEFORE cleanup";
    assert_script_run("snapper cleanup number",  300);    # cleanup created snapshots
    assert_script_run("btrfs quota rescan -w /", 90);
    script_run "echo There are `$snaps_numb` snapshots AFTER cleanup";
    assert_script_run("btrfs qgroup show -pcre /", 3);
    assert_script_run("snapper list");
    clear_console;
    script_run($btrfs_fs_usage);
    # Get actual exclusive disk space to verify exclusive disk space is taken into account
    my $qgroup_excl_space = get_space("btrfs qgroup show  / --raw | grep 1/0 | awk -F ' ' '{print\$3}'");
    if ($qgroup_excl_space > $exp_excl_space) {
        my $msg = "bsc#998360: qgroup 1/0: Exclusive space is above user-defined limit:\n"
          . "$exp_excl_space (expected exclusive disk space) < $qgroup_excl_space (consumed exclusive disk space)";
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

    my ($n_scratch_prepost, $scratchfile_mb, $safety_margin_mb, $initially_free);
    my ($nmax_snapshots, $number_limit_upper_orig, $number_limit_upper, $n);

    # three test parameters; hardcoded values found appropriate in past tests
    $n_scratch_prepost = 3;
    $scratchfile_mb = 1024;
    # Expected to keep the test from filling the last 300 MB of the filesystem, poo#36838
    $safety_margin_mb = 300 + $scratchfile_mb;

    assert_script_run("snapper get-config");    # get initial cfg
    $number_limit_upper_orig = script_output("snapper get-config | awk '/^NUMBER_LIMIT\\>/{ print \$3 }'");
    assert_script_run("snapper list");          # get initial list of snap's

    # check amount of free fs disk space and adapt to it
    $initially_free = get_space("$btrfs_fs_usage | awk -F ' ' '/Free .estimated.:.*min:/{print\$3}'"); # bytes
    $nmax_snapshots = int(($initially_free/1_048_576 - $safety_margin_mb)/$scratchfile_mb) * 2;

    # NUMBER_LIMIT setting such that disk space after cleanup
    # allows another $n_scratch_prepost pre/post snapshot pairs
    $number_limit_upper = $nmax_snapshots - $n_scratch_prepost * 2;
    if ($number_limit_upper > 0) {
        # plenty of free space? No ambition to fill it all, then.
        $number_limit_upper = 18 if ($number_limit_upper > 18);
        assert_script_run "snapper set-config NUMBER_LIMIT=2-$number_limit_upper NUMBER_MIN_AGE=0";
    }  elsif ($number_limit_upper == 0) {
        assert_script_run "snapper set-config NUMBER_LIMIT=0 NUMBER_MIN_AGE=0";
    }  else  {
        # no cleanup test at all will be run in this case, see $n below
        record_soft_failure('WARNING: insufficient disk space left on / for this test');
    }
    assert_script_run("snapper get-config");    # report customized cfg
    assert_script_run("btrfs qgroup show -pc /", 3);
    # Exclusive disk space of qgroup should be ~50% of the fs space as set with SPACE_LIMIT
    $exp_excl_space = get_space("$btrfs_fs_usage | sed -n '2p' | awk -F ' ' '{print\$3}'") / 2;
    # We need to run snapper at least couple of times to ensure it cleans up properly
    # Specifically: Iteration $n - 3 to be the first to actually do clean-ups
    $n = ($number_limit_upper >= 0) ? int(($number_limit_upper+0.5)/($n_scratch_prepost*2)) + 3 : 0;

    for (1 .. $n) { snapper_cleanup($n_scratch_prepost,$scratchfile_mb); }

    # tidy up and restore default settings
    assert_script_run("snapper set-config NUMBER_LIMIT=0; snapper cleanup number; rm -fv data",  300);
    assert_script_run("snapper set-config NUMBER_LIMIT=$number_limit_upper_orig NUMBER_MIN_AGE=1800");
    assert_script_run("snapper get-config; snapper ls");    # final report
    assert_script_run("$btrfs_fs_usage");                   # final report
}

1;

