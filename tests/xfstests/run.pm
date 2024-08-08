# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: xfsprogs
# Summary: Run tests
# - Shuffle the list of xfs tests to run
# - Create heartbeat script, directorie
# - Start heartbeat, setup environment variables
# - Start test from list, write log to file
# - Collect test log and system logs
# - Check if SUT crashed, reset if necessary
# - Save kdump data, unless NO_KDUMP is set to 1
# - Stop heartbeat after last test on list
# - Collect all logs
# Maintainer: Yong Sun <yosun@suse.com>
package run;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;
use Utils::Backends 'is_pvm';
use serial_terminal 'select_serial_terminal';
use power_action_utils qw(power_action prepare_system_shutdown);
use filesystem_utils qw(format_partition generate_xfstests_list);
use lockapi;
use mmapi;
use version_utils 'is_public_cloud';
use LTP::utils;
use LTP::WhiteList;
use xfstests_utils;

# Heartbeat variables
my $HB_INTVL = get_var('XFSTESTS_HEARTBEAT_INTERVAL') || 30;
my $HB_TIMEOUT = get_var('XFSTESTS_HEARTBEAT_TIMEOUT') || 200;
my $HB_PATN = '<h>';    #shorter label <heartbeat> to getting stable under heavy stress
my $HB_DONE = '<d>';    #shorter label <done> to getting stable under heavy stress
my $HB_DONE_FILE = '/opt/test.done';
my $HB_EXIT_FILE = '/opt/test.exit';
my $HB_SCRIPT = '/opt/heartbeat.sh';

# xfstests variables
# - XFSTESTS_RANGES: Set sub tests ranges. e.g. XFSTESTS_RANGES=xfs/100-199 or XFSTESTS_RANGES=generic/010,generic/019,generic/038
# - XFSTESTS_BLACKLIST: Set sub tests not run in XFSTESTS_RANGES. e.g. XFSTESTS_BLACKLIST=generic/010,generic/019,generic/038
# - XFSTESTS_GROUPLIST: Include/Exclude tests in group(a classification by upstream). e.g. XFSTESTS_GROUPLIST='auto,!dangerous_online_repair'
# - XFSTESTS_SUBTEST_MAXTIME: Debug use. To set the max time to wait for sub test to finish. Meet this time frame will trigger reboot, and continue next tests.
# - XFSTESTS: TEST_DEV type, and test in this folder and generic/ folder will be triggered. XFSTESTS=(xfs|btrfs|ext4)
my $TEST_RANGES = get_required_var('XFSTESTS_RANGES');
my $TEST_WRAPPER = '/opt/wrapper.sh';
my $BLACKLIST = get_var('XFSTESTS_BLACKLIST');
my $STATUS_LOG = '/opt/status.log';
my $INST_DIR = '/opt/xfstests';
my $LOG_DIR = '/opt/log';
my $KDUMP_DIR = '/opt/kdump';
my $MAX_TIME = get_var('XFSTESTS_SUBTEST_MAXTIME') || 2400;
my $FSTYPE = get_required_var('XFSTESTS');
my $TEST_SUITE = get_var('TEST');

# Variables use for no heartbeat mode
my $TIMEOUT_NO_HEARTBEAT = get_var('XFSTESTS_TIMEOUT', 2000);
my ($test_status, $test_start, $test_duration);

my $TEST_FOLDER = '/opt/test';
my $SCRATCH_FOLDER = '/opt/scratch';

sub run {
    my $self = shift;
    is_public_cloud() ? select_console('root-console') : select_serial_terminal();
    return if get_var('XFSTESTS_NFS_SERVER');
    my $enable_heartbeat = 1;
    $enable_heartbeat = 0 if (check_var 'XFSTESTS_NO_HEARTBEAT', '1');

    config_debug_option;

    # Load whitelist environment
    my $whitelist_env = prepare_whitelist_environment();

    # Get wrapper
    assert_script_run("curl -o $TEST_WRAPPER " . data_url('xfstests/wrapper.sh'));
    assert_script_run("chmod a+x $TEST_WRAPPER");

    # Get test list
    my @tests = tests_from_ranges($TEST_RANGES, $INST_DIR);
    my %uniq;
    @tests = (@tests, include_grouplist);
    @tests = grep { ++$uniq{$_} < 2; } @tests;

    # Shuffle tests list
    unless (get_var('NO_SHUFFLE')) {
        @tests = shuffle(@tests);
    }

    heartbeat_prepare if $enable_heartbeat == 1;
    assert_script_run("mkdir -p $KDUMP_DIR $LOG_DIR");

    # wait until nfs service is ready
    if (get_var('PARALLEL_WITH')) {
        mutex_wait('xfstests_nfs_server_ready');
        script_retry('ping -c3 10.0.2.101', delay => 15, retry => 12);
    }

    heartbeat_start if $enable_heartbeat == 1;

    # Generate xfstests blacklist
    my %black_list = (generate_xfstests_list($BLACKLIST), exclude_grouplist);
    if (my $issues = get_var('XFSTESTS_KNOWN_ISSUES')) {
        my $whitelist = LTP::WhiteList->new($issues);
        my %skipped = map { $_ => 1 } $whitelist->list_skipped_tests($whitelist_env, $TEST_SUITE);
        %black_list = (%black_list, %skipped);
    }

    my $status_log_content = "";
    foreach my $test (@tests) {
        # trim testname
        $test =~ s/^\s+|\s+$//g;
        # Skip tests inside blacklist
        if (exists($black_list{$test})) {
            next;
        }

        umount_xfstests_dev unless get_var('XFSTESTS_HIGHSPEED');

        # Run test and wait for it to finish
        my ($category, $num) = split(/\//, $test);
        enter_cmd("echo $test > /dev/$serialdev");
        if ($enable_heartbeat == 0) {
            $status_log_content = test_run_without_heartbeat($self, $test);
            next;
        }
        test_run($test);
        my ($type, $status, $time) = test_wait($MAX_TIME);
        if ($type eq $HB_DONE) {
            # Test finished without crashing SUT
            $status_log_content = log_add($STATUS_LOG, $test, $status, $time);
            copy_all_log($category, $num) if ($status =~ /FAILED/);
            next;
        }

        # Here script already know the SUT crashed/hanged.
        # To adapt two scenarios:
        # 1. system hang in root console during run subtests;
        # 2. system already crash and reboot by itself and waiting in bootloader screen.
        # Here to reboot "again" to keep logic and real screen in the same page. After reboot to continue the rest tests.
        eval {
            prepare_system_shutdown;
            check_var('VIRTIO_CONSOLE', '1') ? power('reset') : send_key 'alt-sysrq-b';
            reconnect_mgmt_console if is_pvm;
            $self->wait_boot;
        };

        sleep(1);
        select_console('root-console');
        # Save kdump data to KDUMP_DIR if not set "NO_KDUMP=1"
        unless (check_var('NO_KDUMP', '1')) {
            unless (save_kdump($test, $KDUMP_DIR, vmcore => 1, kernel => 1, debug => 1)) {
                # If no kdump data found, write warning to log
                my $msg = "Warning: $test crashed SUT but has no kdump data";
                script_run("echo '$msg' >> $LOG_DIR/$category/$num");
            }
        }

        # Add test status to STATUS_LOG file
        log_add($STATUS_LOG, $test, $status, $time);

        # Reload loop device after a reboot
        reload_loop_device if get_var('XFSTESTS_LOOP_DEVICE');

        # Prepare for the next test
        heartbeat_start;
    }
    heartbeat_stop if $enable_heartbeat == 1;

    #Save status log before next step(if run.pm fail will load into a last good snapshot)
    save_tmp_file('status.log', $status_log_content);
    my $local_file = "/tmp/opt_logs.tar.gz";
    script_run("tar zcvf $local_file --absolute-names /opt/log/", timeout => 600, die_on_timeout => 0);
    upload_logs($local_file, failok => 1, timeout => 180);
}

sub test_flags {
    return {fatal => 0};
}

sub post_fail_hook {
    my ($self) = shift;
    # Collect executed test logs
    script_run('tar zcvf /tmp/opt_logs.tar.gz --absolute-names /opt/log/', timeout => 600, die_on_timeout => 0);
    upload_logs('/tmp/opt_logs.tar.gz', failok => 1, timeout => 180);
}

1;
