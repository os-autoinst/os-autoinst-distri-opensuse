# SUSE's openQA tests
#
# Copyright 2018-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: xfsprogs
# Summary: Run xfstests
# - Shuffle the list of xfs tests to run
# - Create heartbeat script, directorie
# - Start heartbeat, setup environment variables
# - Start test from list, write log to file
# - Collect test log and system logs
# - Check if SUT crashed, reset if necessary
# - Save kdump data, unless NO_KDUMP is set to 1
# - Stop heartbeat after last test on list
# - Collect all logs
# Maintainer: Yong Sun <yosun@suse.com>, An Long <lan@suse.com>
package run;

use 5.018;
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
use lockapi;

# xfstests general variables
# - XFSTESTS_RANGES: Set sub tests ranges. e.g. XFSTESTS_RANGES=xfs/100-199 or XFSTESTS_RANGES=generic/010,generic/019,generic/038
# - XFSTESTS_BLACKLIST: Set sub tests not run in XFSTESTS_RANGES. e.g. XFSTESTS_BLACKLIST=generic/010,generic/019,generic/038
# - XFSTESTS_GROUPLIST: Include/Exclude tests in group(a classification by upstream). e.g. XFSTESTS_GROUPLIST='auto,!dangerous_online_repair'
# - XFSTESTS_SUBTEST_MAXTIME: Debug use. To set the max time to wait for sub test to finish. Meet this time frame will trigger reboot, and continue next tests.
# - XFSTESTS: TEST_DEV type, and test in this folder and generic/ folder will be triggered. XFSTESTS=(xfs|btrfs|ext4)
my $TEST_RANGES = get_required_var('XFSTESTS_RANGES');
my $TEST_WRAPPER = '/opt/wrapper.sh';
my $BLACKLIST = get_var('XFSTESTS_BLACKLIST');
my $GROUPLIST = get_var('XFSTESTS_GROUPLIST');
my $STATUS_LOG = '/opt/status.log';
my $INST_DIR = '/opt/xfstests';
my $LOG_DIR = '/opt/log';
my $KDUMP_DIR = '/opt/kdump';
my $SUBTEST_MAX_TIME = get_var('XFSTESTS_SUBTEST_MAXTIME') || 2400;
my $FSTYPE = get_required_var('XFSTESTS');
my $TEST_SUITE = get_var('TEST');
my $ENABLE_KDUMP = check_var('NO_KDUMP', '1') ? 0 : 1;
#my $VIRTIO_CONSOLE = get_var('VIRTIO_CONSOLE');

# variables set by previous steps
my $TEST_DEV = get_var('XFSTESTS_TEST_DEV');
my $SCRATCH_DEV = get_var('XFSTESTS_SCRATCH_DEV');
my $SCRATCH_DEV_POOL = get_var('XFSTESTS_SCRATCH_DEV_POOL');
my $LOOP_DEVICE = get_var('XFSTESTS_LOOP_DEVICE');

# Debug variables
# - INJECT_INFO: inject a line or more line into xfstests subtests for debugging.
# - RAW_DUMP: set it a non-zero value to enable raw dump by dd the super block.
# - XFSTESTS_DEBUG: enable collect more info by set 1 to files under /proc/sys/kernel/, more than 1 info split by space
#     e.g. "hardlockup_panic hung_task_panic panic_on_io_nmi panic_on_oops panic_on_rcu_stall..."
my $INJECT_INFO = get_var('INJECT_INFO', '');
my $RAW_DUMP = get_var('RAW_DUMP', 0);
my $DEBUG_INFO = get_var('XFSTESTS_DEBUG', '');

# Heartbeat mode variables
# - XFSTESTS_HEARTBEAT_INTERVAL: Set how long to send/receive a heartbeat
# - XFSTESTS_HEARTBEAT_TIMEOUT: Set the threshold to decide lose heartbeat
my $HB_INTVL = get_var('XFSTESTS_HEARTBEAT_INTERVAL') || 30;
my $HB_TIMEOUT = get_var('XFSTESTS_HEARTBEAT_TIMEOUT') || 200;
my $HB_DONE = '<d>';

# None heartbeat mode variables
# - XFSTESTS_TIMEOUT: Set the sub-test timeout threshold
my $TIMEOUT_NO_HEARTBEAT = get_var('XFSTESTS_TIMEOUT', 2000);


sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    return if get_var('XFSTESTS_NFS_SERVER');
    my $enable_heartbeat = 1;
    $enable_heartbeat = 0 if (check_var 'XFSTESTS_NO_HEARTBEAT', '1');

    config_debug_option($DEBUG_INFO);

    # Load whitelist environment
    my $whitelist_env = prepare_whitelist_environment();

    # Get wrapper
    assert_script_run("curl -o $TEST_WRAPPER " . data_url('xfstests/wrapper.sh'));
    assert_script_run("chmod a+x $TEST_WRAPPER");

    # Get test list
    my @tests = tests_from_ranges($TEST_RANGES, $INST_DIR);
    my %uniq;
    @tests = (@tests, include_grouplist($TEST_RANGES, $GROUPLIST, $FSTYPE));
    @tests = grep { ++$uniq{$_} < 2; } @tests;

    # Shuffle tests list
    unless (get_var('NO_SHUFFLE')) {
        @tests = shuffle(@tests);
    }

    heartbeat_prepare($HB_INTVL) if $enable_heartbeat;
    assert_script_run("mkdir -p $KDUMP_DIR $LOG_DIR");

    # wait until nfs service is ready
    if (get_var('PARALLEL_WITH')) {
        mutex_wait('xfstests_nfs_server_ready');
        script_retry('ping -c3 10.0.2.101', delay => 15, retry => 12);
    }

    # Generate xfstests blacklist
    my %black_list = (generate_xfstests_list($BLACKLIST), exclude_grouplist($TEST_RANGES, $GROUPLIST, $FSTYPE));
    my $whitelist;
    if (my $issues = get_var('XFSTESTS_KNOWN_ISSUES')) {
        $whitelist = LTP::WhiteList->new($issues);
    }

    my $subtest_num = scalar @tests;
    foreach my $index (0 .. $#tests) {
        my $test = $tests[$index];
        # trim testname
        $test =~ s/^\s+|\s+$//g;
        # Skip tests inside blacklist
        if (exists($black_list{$test}) || ($whitelist && $whitelist->is_test_disabled($whitelist_env, $TEST_SUITE, $test))) {
            next;
        }
        my $targs = OpenQA::Test::RunArgs->new();
        # Change / to -, because openqa will see / as path and it'll fail to find run file in loadtest
        $test =~ s/\//-/;
        $targs->{name} = $test;
        $targs->{enable_heartbeat} = $enable_heartbeat;
        $targs->{last_one} = 0;
        $targs->{my_instance} = $args->{my_instance} if is_public_cloud;
        if ($index == $subtest_num - 1) {
            mutex_create 'last_subtest_run_finish';
            $targs->{last_one} = 1;
            autotest::loadtest("tests/xfstests/run_subtest.pm", name => $test, run_args => $targs);
            mutex_lock 'last_subtest_run_finish';
            autotest::loadtest 'tests/xfstests/generate_report.pm';
            autotest::loadtest("tests/publiccloud/ssh_interactive_end.pm", run_args => $args) if is_public_cloud();
        }
        else {
            autotest::loadtest("tests/xfstests/run_subtest.pm", name => $test, run_args => $targs);
        }
    }
}

sub test_flags {
    return {
        fatal => 1,
        milestone => 1,
    };
}

sub post_fail_hook {
    return;
}

1;
