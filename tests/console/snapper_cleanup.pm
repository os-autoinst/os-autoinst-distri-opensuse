# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: snapper btrfsprogs
# Summary: Snapper cleanup test based on FATE#312751
# - In case of upgrade or BOOT_TO_SNAPSHOT not set
#   - Run snapper setup-quota
#   - snapper set-config NUMBER_LIMIT_IMPORTANT=4-10 SPACE_LIMIT=0.5
# - Get initial cfg and save initial NUMBER_LIMIT, NUMBER_MIN_AGE and SPACE_LIMIT settings for later restore
# - Remove non-important number snapshots so the test starts from a known state
# - Set NUMBER_LIMIT to one iteration of pre/post pairs and SPACE_LIMIT a
#   little above the current qgroup usage
# - Create pre/post pairs that keep a scratch file of exclusive space each and
#   check that SPACE_LIMIT makes snapper cleanup go below the NUMBER_LIMIT upper bound
# - Cleanup
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use Mojo::Base 'btrfs_test';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'clear_console';
use version_utils qw(is_sle is_tumbleweed is_leap);

my $btrfs_fs_usage = 'btrfs filesystem usage / --raw';
# /root, /var etc. are subvolumes that the snapper root config does not snapshot
my $scratch_dir = '/snapper-cleanup-test';
my $snap_desc = 'snapper_cleanup_test';
my $n_scratch_prepost = 3;
my $scratchfile_mb = 256;
my $number_limit_upper = 2 * $n_scratch_prepost;
# SPACE_LIMIT is set this far above the initial qgroup usage. Snapper checks
# the usage right after deleting snapshots, while one scratch file is still
# shared with a deleted snapshot, so it sees two scratch files after the
# NUMBER_LIMIT cleanup. The margin must stay below that.
my $space_margin_mb = 384;
my $space_limit_bytes;

sub get_space {
    my ($script) = @_;
    my $script_output = script_output($script, timeout => 120);
    return $script_output;
}

# Exclusive space of the snapper qgroup once btrfs dropped deleted snapshots
sub qgroup_excl_space {
    my $excl = script_output("sync && btrfs subvolume sync / >/dev/null && btrfs quota rescan -w / >/dev/null && btrfs qgroup show --raw / | awk '\$1 == \"1/0\" {print \$3}'", timeout => 300);
    die "Could not read the exclusive space of qgroup 1/0: '$excl'" unless $excl =~ /^\d+$/;
    return $excl;
}

sub snapper_cleanup {
    my ($self) = @_;
    my $snaps_numb = "snapper list | grep number | wc -l";

    script_run($btrfs_fs_usage, 120);
    # we want to fill up disk enough so that snapper cleanup triggers
    my $fill_space = "dd if=/dev/urandom of=$scratch_dir/data bs=1M count=$scratchfile_mb";
    my $snap_create = "snapper create --cleanup number --description $snap_desc --command '$fill_space'";
    assert_script_run "btrfs filesystem show --mbytes /";

    for (1 .. $n_scratch_prepost) { assert_script_run("$snap_create", 500); }
    assert_script_run('sync');
    script_run "echo There are `$snaps_numb` snapshots BEFORE cleanup";
    # cleanup created snapshots
    # softfail the test if hitting bsc#1206814, so that the subsequent test runs are not affected
    my $output = script_output('snapper cleanup number || echo "error detected"', 300, proceed_on_failure => 1);
    if ($output =~ m/error detected/) {
        if (($output =~ m/Failure\s+\(error\.something\)\./) && is_leap) {
            record_soft_failure 'bsc#1206814';
            $self->{softfailed} = 1;
            return;
        }
        die 'snapper cleanup number failed';
    }
    my $qgroup_excl_space = qgroup_excl_space();
    # pipefail makes a failing snapper list fail here instead of counting 0
    my $test_snaps = script_output("snapper list | awk '/$snap_desc/ {n++} END {print n + 0}'");
    # Only the SPACE_LIMIT cleanup goes below the NUMBER_LIMIT upper bound
    $self->{space_cleanups}++ if $test_snaps < $number_limit_upper;
    record_info('cleanup', "test snapshots: $test_snaps, qgroup 1/0 exclusive: $qgroup_excl_space, SPACE_LIMIT: $space_limit_bytes");
    script_run "echo There are `$snaps_numb` snapshots AFTER cleanup";
    assert_script_run("btrfs qgroup show -pcre /");
    assert_script_run("snapper list");
    clear_console unless testapi::is_serial_terminal();
    script_run($btrfs_fs_usage, 120);
    # The scratch file shared with the last deleted snapshot is exclusive by
    # now, which snapper could not see yet
    my $max_excl_space = $space_limit_bytes + $scratchfile_mb * 1024 * 1024;
    if ($qgroup_excl_space > $max_excl_space) {
        my $msg = "bsc#998360: qgroup 1/0: Exclusive space is above user-defined limit plus one scratch file:\n"
          . "$max_excl_space (expected exclusive disk space) < $qgroup_excl_space (consumed exclusive disk space)";
        if (check_var('VERSION', '12-SP2')) {
            record_info('Softfail', $msg, result => 'softfail');
        }
        else {
            die $msg;
        }
    }
}

sub run {
    my $self = shift;
    select_serial_terminal;
    $self->cron_mock_lastrun() if is_sle('<15');

    if (get_var("UPGRADE") || get_var("AUTOUPGRADE") && !get_var("BOOT_TO_SNAPSHOT")) {
        assert_script_run "snapper setup-quota";
        # Note: Later, NUMBER_LIMIT will be customized (unconditionally), too
        assert_script_run "snapper set-config NUMBER_LIMIT_IMPORTANT=4-10 SPACE_LIMIT=0.5";
    }

    my ($number_limit_pre, $number_min_age_pre, $space_limit_pre);

    # get initial cfg and save initial NUMBER_LIMIT, NUMBER_MIN_AGE and SPACE_LIMIT settings for later restore
    assert_script_run("snapper get-config");
    # Read the config file, the get-config table layout differs between snapper versions
    foreach (split /\n/, script_output('grep -E "^(NUMBER_LIMIT|NUMBER_MIN_AGE|SPACE_LIMIT)=" /etc/snapper/configs/root')) {
        $number_limit_pre = $1 if (m/^NUMBER_LIMIT="?([-\d]+)"?\s*$/);
        $number_min_age_pre = $1 if (m/^NUMBER_MIN_AGE="?(\d+)"?\s*$/);
        $space_limit_pre = $1 if (m/^SPACE_LIMIT="?([^"\s]+)"?\s*$/);
    }
    die 'Could not read NUMBER_LIMIT, NUMBER_MIN_AGE and SPACE_LIMIT from /etc/snapper/configs/root'
      unless defined $number_limit_pre && defined $number_min_age_pre && defined $space_limit_pre;
    $self->{config_restore} = "NUMBER_LIMIT=$number_limit_pre NUMBER_MIN_AGE=$number_min_age_pre SPACE_LIMIT=$space_limit_pre";
    assert_script_run("snapper list");    # get initial list of snap's

    # Start without non-important number snapshots, the end of the test removes them anyway.
    # The cleanup with a NUMBER_LIMIT range is quota aware and adds all
    # snapshots with a cleanup algorithm to the snapper qgroup, which the
    # test then measures.
    assert_script_run("snapper set-config NUMBER_LIMIT=0 NUMBER_MIN_AGE=0 && snapper cleanup number && "
          . "snapper set-config NUMBER_LIMIT=2-$number_limit_upper && snapper cleanup number && rm -rf $scratch_dir && mkdir $scratch_dir", 300);
    my ($scratch_subvol, $root_subvol) = split /\s+/, script_output("btrfs inspect-internal rootid $scratch_dir; btrfs inspect-internal rootid /");
    die "$scratch_dir is in subvolume $scratch_subvol, not in the snapshotted subvolume $root_subvol" unless $scratch_subvol eq $root_subvol;

    # Room for SPACE_LIMIT, two iterations and the live scratch file. Keep the
    # test from filling the last 300 MB of the filesystem, poo#36838
    my $needed_mb = $space_margin_mb + (2 * $n_scratch_prepost + 1) * $scratchfile_mb + 300;
    my $initially_free = get_space("$btrfs_fs_usage | awk -F ' ' '/Free .estimated.:.*min:/{print\$3}'");    # bytes
    die("Insufficient initial disk space left on / to run this test: $initially_free bytes")
      if $initially_free / (1024 * 1024) < $needed_mb;

    # Snapper compares the qgroup usage with the statvfs size of the filesystem
    my ($blocks, $bsize) = split /\s+/, script_output("stat -f -c '%b %s' /");
    my $space_limit = sprintf('%.6f', (qgroup_excl_space() + $space_margin_mb * 1024 * 1024) / ($blocks * $bsize));
    $space_limit_bytes = int($space_limit * $blocks * $bsize);
    assert_script_run "snapper set-config SPACE_LIMIT=$space_limit";
    assert_script_run("snapper get-config");    # report customized cfg
    assert_script_run("btrfs qgroup show -pc /");
    # Every iteration exceeds SPACE_LIMIT and from the second one on also
    # NUMBER_LIMIT, so three iterations exercise both cleanups
    for (1 .. 3) { $self->snapper_cleanup(); }
    die 'SPACE_LIMIT never made snapper cleanup remove a snapshot' unless $self->{space_cleanups} || $self->{softfailed};

    # tidy up and restore default settings
    assert_script_run("snapper set-config NUMBER_LIMIT=0; snapper cleanup number; rm -rfv $scratch_dir", 300);
    assert_script_run("snapper set-config $self->{config_restore}");
    assert_script_run("snapper get-config");    # final report
        # command 'snapper ls' runs timeout or it stucks because of display used space, so we have to disable it on tumbleweed, see poo#122557
    my $command_args = (is_tumbleweed && check_var('MACHINE', '64bit')) ? '--disable-used-space' : undef;
    assert_script_run("snapper ls $command_args", 30);
    assert_script_run("$btrfs_fs_usage", 120);    # final report
}

sub post_fail_hook {
    my ($self) = @_;
    my $logs_ok = eval { $self->SUPER::post_fail_hook; 1 };
    my $logs_error = $@;
    # Only coverage runs continue without a rollback, so only they need to
    # undo the changes of run(). Coverage runs use Tumbleweed without UPGRADE,
    # so NUMBER_LIMIT, NUMBER_MIN_AGE and SPACE_LIMIT are the only settings changed.
    $self->restore_snapper_state if get_var('BINARY_COVERAGE') && $self->{config_restore};
    die $logs_error unless $logs_ok;
}

sub restore_snapper_state {
    my ($self) = @_;
    select_console('log-console');
    my @commands = (
        # A timed out 'snapper create' or 'dd' may still run on the serial terminal
        q{pkill -x snapper; pkill -x dd; timeout 60 sh -c 'while pgrep -x "snapper|dd" >/dev/null; do sleep 1; done'},
        "snapper set-config NUMBER_LIMIT=0; snapper cleanup number; rm -rfv $scratch_dir",
        "snapper set-config $self->{config_restore}",
    );
    for my $cmd (@commands) {
        eval { script_run($cmd, timeout => 300) };
        record_info('cleanup failed', "$cmd\n$@", result => 'fail') if $@;
    }
}

sub test_flags {
    my ($self) = @_;
    # Keep the instrumented system and its coverage data instead of aborting.
    return {fatal => 0, no_rollback => 1} if get_var('BINARY_COVERAGE');
    return $self->SUPER::test_flags();
}

1;

