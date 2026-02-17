# SUSE's openQA tests
#
# Copyright 2018-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: xfsprogs
# Summary: Run single xfstests subtest
# Maintainer: Yong Sun <yosun@suse.com>, An Long <lan@suse.com>

use 5.018;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use utils;
use Utils::Backends qw(is_pvm is_svirt);
use Utils::Architectures qw(is_s390x);
use serial_terminal 'select_serial_terminal';
use power_action_utils qw(prepare_system_shutdown assert_shutdown_and_restore_system);
use filesystem_utils qw(format_partition generate_xfstests_list);
use lockapi;
use mmapi;
use version_utils 'is_public_cloud';
use LTP::utils;
use LTP::WhiteList;
use bugzilla;
use xfstests_utils;
use lockapi;

# xfstests general variables
# - XFSTESTS_RANGES: Set sub tests ranges. e.g. XFSTESTS_RANGES=xfs/100-199 or XFSTESTS_RANGES=generic/010,generic/019,generic/038
# - XFSTESTS_BLACKLIST: Set sub tests not run in XFSTESTS_RANGES. e.g. XFSTESTS_BLACKLIST=generic/010,generic/019,generic/038
# - XFSTESTS_GROUPLIST: Include/Exclude tests in group(a classification by upstream). e.g. XFSTESTS_GROUPLIST='auto,!dangerous_online_repair'
# - XFSTESTS_SUBTEST_MAXTIME: Debug use. To set the max time to wait for sub test to finish. Meet this time frame will trigger reboot, and continue next tests.
# - XFSTESTS: TEST_DEV type, and test in this folder and generic/ folder will be triggered. XFSTESTS=(xfs|btrfs|ext4)
my $STATUS_LOG = '/opt/status.log';
my $INST_DIR = '/opt/xfstests';
my $LOG_DIR = '/opt/log';
my $KDUMP_DIR = '/opt/kdump';
my $SUBTEST_MAX_TIME = get_var('XFSTESTS_SUBTEST_MAXTIME', 2400);
my $FSTYPE = get_required_var('XFSTESTS');
my $TEST_SUITE = get_var('TEST');
my $ENABLE_KDUMP = check_var('NO_KDUMP', '1') ? 0 : 1;
my $VIRTIO_CONSOLE = get_var('VIRTIO_CONSOLE');

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

# Heartbeat mode variables
# - XFSTESTS_HEARTBEAT_INTERVAL: Set how long to send/receive a heartbeat
# - XFSTESTS_HEARTBEAT_TIMEOUT: Set the threshold to decide lose heartbeat
my $HB_TIMEOUT = get_var('XFSTESTS_HEARTBEAT_TIMEOUT', 200);
my $HB_DONE = '<d>';

# None heartbeat mode variables
# - XFSTESTS_TIMEOUT: Set the sub-test timeout threshold
my $TIMEOUT_NO_HEARTBEAT = get_var('XFSTESTS_TIMEOUT', 2000);

my ($type, $status, $time, $test_timeout);
my $whitelist_env = prepare_whitelist_environment();
my %softfail_list = generate_xfstests_list(get_var('XFSTESTS_SOFTFAIL'));

sub override_known_failures {
    my ($self) = @_;
    my $targs = $self->{targs};
    my $result_args = $self->{result_args};
    my $whitelist_url = get_var('XFSTESTS_KNOWN_ISSUES');
    my %args = (result => 'ok');
    my $whitelist;
    my $whitelist_entry;

    $whitelist = LTP::WhiteList->new($whitelist_url) if $whitelist_url;
    $whitelist_entry = $whitelist->find_whitelist_entry($whitelist_env, $TEST_SUITE, $targs->{name}) if defined($whitelist);
    check_bugzilla_status($whitelist_entry, $targs) if $whitelist_entry;

    $self->record_resultfile('INFO', "name: $targs->{name}\ntest result: $result_args->{status}\ntime: $result_args->{time}\n", %args);
    $self->record_resultfile('output', "$targs->{output}", %args) if defined($targs->{output});
    $self->record_resultfile('out.bad', "$targs->{outbad}", %args) if defined($targs->{outbad});
    $self->record_resultfile('full', "$targs->{fullog}", %args) if defined($targs->{fullog});
    $self->record_resultfile('dmesg', "$targs->{dmesg}", %args) if defined($targs->{dmesg});

    if ($targs->{status} =~ /SOFTFAILED/) {
        $self->record_soft_failure_result($targs->{failinfo}, force_status => 1, %args) if defined($targs->{failinfo});
        $self->record_resultfile('bugzilla', "$targs->{bugzilla}", %args) if defined($targs->{bugzilla});
    }
    else {
        $self->{result} = 'fail';
        $self->record_resultfile('known', "$targs->{failinfo}", %args) if defined($targs->{failinfo});
        $self->record_resultfile('bugzilla', "$targs->{bugzilla}", %args) if defined($targs->{bugzilla});
    }
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    (my $test = $args->{name}) =~ s/-/\//;
    my $enable_heartbeat = $args->{enable_heartbeat};
    my $is_last_one = $args->{last_one};
    umount_xfstests_dev($TEST_DEV, $SCRATCH_DEV, $SCRATCH_DEV_POOL) unless get_var('XFSTESTS_HIGHSPEED');
    my ($category, $num) = split(/\//, $test);
    my $status_log_content = "";
    my %targs = (name => $test, status => 'FAILED', time => 'timeout');

    $self->{targs} = \%targs;
    $self->{result_args} = {status => 'FAILED', time => 'timeout'};

    $whitelist_env->{kernel} = script_output('uname -r');
    $whitelist_env->{libc} = script_output('rpm -q glibc');
    $whitelist_env->{gcc} = script_output('rpm -q gcc');
    $whitelist_env->{ltp_version} = script_output('rpm -q xfstests');
    enter_cmd("echo $test > /dev/$serialdev");
    if ($enable_heartbeat == 0) {
        $self->{result_args} = test_run_without_heartbeat($self, $test, $TIMEOUT_NO_HEARTBEAT, $FSTYPE, $RAW_DUMP, $SCRATCH_DEV, $SCRATCH_DEV_POOL, $INJECT_INFO, $LOOP_DEVICE, $ENABLE_KDUMP, $VIRTIO_CONSOLE, 0, $args->{my_instance});
        $status = $self->{result_args}->{status};
        $time = $self->{result_args}->{time};
        $status_log_content = $self->{result_args}->{output};
        $test_timeout = $self->{result_args}->{timeout};
    }
    else {
        my $result_args = {};
        heartbeat_start;
        test_run($test, $FSTYPE, $INJECT_INFO);
        ($type, $status, $time) = test_wait($SUBTEST_MAX_TIME, $HB_TIMEOUT, $VIRTIO_CONSOLE);
        $result_args->{type} = $type;
        $result_args->{status} = $status;
        $result_args->{time} = $time;
        $self->{result_args} = $result_args;
        if ($type eq $HB_DONE) {
            # Test finished without crashing SUT
            $status_log_content = log_add($STATUS_LOG, $test, $status, $time);
            copy_all_log($category, $num, $FSTYPE, $RAW_DUMP, $SCRATCH_DEV, $SCRATCH_DEV_POOL) if ($status =~ /FAILED/);
        }
        else {
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
            if ($ENABLE_KDUMP) {
                unless (save_kdump($test, $KDUMP_DIR, vmcore => 1, kernel => 1, debug => 1)) {
                    # If no kdump data found, write warning to log
                    my $msg = "Warning: $test crashed SUT but has no kdump data";
                    script_run("echo '$msg' >> $LOG_DIR/$category/$num");
                }
            }
            # Add test status to STATUS_LOG file
            log_add($STATUS_LOG, $test, $status, $time);

            # Reload loop device after a reboot
            reload_loop_device($self, $FSTYPE) if get_var('XFSTESTS_LOOP_DEVICE');
        }
        heartbeat_stop($VIRTIO_CONSOLE);
    }

    (my $generate_name = $test) =~ s/-/\//;
    my $test_path = '/opt/log/' . $generate_name;
    bmwqemu::fctinfo("$generate_name");
    my $whitelist_entry;
    my $output_message;
    if ($test_timeout) {
        $output_message = 'Test run timeout, it was terminated by wrapper. Find more info in serial0.txt';
    }
    else {
        $output_message = 'No log in test path, find log in serial0.txt';
    }
    $targs{output} = script_output("if [ -f $test_path ]; then tail -n 200 $test_path | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; else echo '$output_message'; fi", 600, type_command => 1, proceed_on_failure => 1);
    $targs{time} = $time;
    $targs{status} = $status;
    if ($status =~ /SKIPPED/) {
        $self->{result} = 'skip';
    }
    elsif ($status =~ /FAILED|SOFTFAILED/) {
        $self->{result} = 'fail';
        $targs{outbad} = script_output("if [ -f $test_path.out.bad ]; then tail -n 200 $test_path.out.bad | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; else echo '$test_path.out.bad not exist';fi", 600, type_command => 1, proceed_on_failure => 1);
        $targs{fullog} = script_output("if [ -f $test_path.full ]; then tail -n 200 $test_path.full | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; else echo '$test_path.full not exist'; fi", 600, type_command => 1, proceed_on_failure => 1);
        $targs{dmesg} = script_output("if [ -f $test_path.dmesg ]; then tail -n 200 $test_path.dmesg | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; fi", 600, type_command => 1, proceed_on_failure => 1);
        $targs{status} = 'SOFTFAILED' if $status =~ /SOFTFAILED/;

        if (exists($softfail_list{$generate_name})) {
            $targs{status} = 'SOFTFAILED';
            $targs{failinfo} = 'XFSTESTS_SOFTFAIL set in configuration';
        }
    }
    else {
        record_info('INFO', "name: $test\ntest result: $status\ntime: $time\n");
        record_info('output', "$targs{output}");
    }
    if ($is_last_one) {
        mutex_unlock 'last_subtest_run_finish';
    }
    # s390x will not load to new snapshot automatically
    if ($test_timeout && is_s390x && is_svirt) {
        assert_shutdown_and_restore_system;
        reconnect_mgmt_console;
    }
}

sub test_flags {
    return {fatal => 0};
}

sub post_fail_hook {
    my ($self) = @_;

    $self->override_known_failures() if $self->{result} eq 'fail';
}

1;
