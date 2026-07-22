# SUSE's openQA tests
#
# Copyright 2018-2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: xfsprogs
# Summary: Run single xfstests subtest
# Maintainer: Yong Sun <yosun@suse.com>, An Long <lan@suse.com>

## no os-autoinst compile-check

use 5.018;
use Mojo::Base 'opensusebasetest';
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
use xfstests_ai_analysis;
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
# - XFSTESTS_CLEAN_BEFORE_TEST: Clean before run test in wrapper
#     e.g. ""XFSTESTS_CLEAN_BEFORE_TEST = 'xfs/250-252,xfs/259'
my $INJECT_INFO = get_var('INJECT_INFO', '');
my $RAW_DUMP = get_var('RAW_DUMP', 0);
my $XFSTESTS_DEEP_CLEAN = get_var('XFSTESTS_CLEAN_BEFORE_TEST');

# Heartbeat mode variables
# - XFSTESTS_HEARTBEAT_INTERVAL: Set how long to send/receive a heartbeat
# - XFSTESTS_HEARTBEAT_TIMEOUT: Set the threshold to decide lose heartbeat
my $HB_TIMEOUT = get_var('XFSTESTS_HEARTBEAT_TIMEOUT', 200);
my $HB_DONE = '<d>';

# None heartbeat mode variables
# - XFSTESTS_TIMEOUT: Set the sub-test timeout threshold
my $TIMEOUT_NO_HEARTBEAT = get_var('XFSTESTS_TIMEOUT', 2000);

# Sporadic debug variables (only used when a subtest is tagged sporadic by run.pm)
# - DEBUG_SPORADIC_LOOP: iterations (fixed) or consecutive passes required (until_pass). Default 10
# - DEBUG_SPORADIC_MODE: fixed (default), until_fail, until_pass
# - DEBUG_SPORADIC_MAX: hard iteration cap for until_pass mode (default 20)
my $SPORADIC_LOOP = get_var('DEBUG_SPORADIC_LOOP', 10);
my $SPORADIC_MODE = get_var('DEBUG_SPORADIC_MODE', 'fixed');
my $SPORADIC_MAX = get_var('DEBUG_SPORADIC_MAX', 20);
# Keep artifacts under LOG_DIR so generate_report.pm uploads them automatically
my $SPORADIC_DIR = "$LOG_DIR/sporadic_debug";

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

# Run a single subtest once, reusing the same execution paths as the normal
# run() below so both heartbeat and non-heartbeat modes behave identically to a
# regular run. Returns ($status, $duration).
sub run_sporadic_once {
    my ($self, $test, $enable_heartbeat, $my_instance) = @_;
    my ($category, $num) = split(/\//, $test);

    # Each iteration starts from a clean, unmounted state, like a normal run.
    umount_xfstests_dev($TEST_DEV, $SCRATCH_DEV, $SCRATCH_DEV_POOL) unless get_var('XFSTESTS_HIGHSPEED');
    enter_cmd("echo $test > /dev/$serialdev");

    my ($status, $duration);
    # Non-heartbeat mode: test_run_without_heartbeat runs the test, waits for it
    # and recovers from a crash internally, returning status and duration.
    unless ($enable_heartbeat) {
        my $result = test_run_without_heartbeat(
            $self, $test, $TIMEOUT_NO_HEARTBEAT, $FSTYPE, $RAW_DUMP,
            $SCRATCH_DEV, $SCRATCH_DEV_POOL, $XFSTESTS_DEEP_CLEAN, $INJECT_INFO,
            $LOOP_DEVICE, $ENABLE_KDUMP, $VIRTIO_CONSOLE, 0, $my_instance);
        ($status, $duration) = ($result->{status}, $result->{time});
        return ($result->{status}, $result->{time});
    }
    # Heartbeat mode: start the heartbeat, run the test, wait for the done marker
    # and recover the SUT if the heartbeat is lost.
    else {
        heartbeat_start;
        test_run($test, $FSTYPE, $XFSTESTS_DEEP_CLEAN, $INJECT_INFO);
        my $type;
        ($type, $status, $duration) = test_wait($SUBTEST_MAX_TIME, $HB_TIMEOUT, $VIRTIO_CONSOLE);
        if ($type eq $HB_DONE) {
            copy_all_log($category, $num, $FSTYPE, $RAW_DUMP, $SCRATCH_DEV, $SCRATCH_DEV_POOL) if $status =~ /FAILED/;
        }
        else {
            recover_after_crash($self, $test, $FSTYPE, $ENABLE_KDUMP, $my_instance);
        }
        heartbeat_stop($VIRTIO_CONSOLE);
    }

    # On failure, push the key logs to the openQA result DB via record_info so
    # they survive a later snapshot rollback that would wipe the /opt/log tarball.
    if ($status =~ /FAILED/) {
        for my $ext (qw(out.bad full dmesg)) {
            my $f = "$INST_DIR/results/$category/$num.$ext";
            record_info("$num.$ext", script_output(
                    "if [ -f $f ]; then tail -n 200 $f | tr -cd '\\11\\12\\15\\40-\\176'; else echo '$f: not found'; fi",
                    120, proceed_on_failure => 1));
        }
    }
    return ($status, $duration);
}

# Snapshot free memory and disk usage into the iteration directory.
sub snapshot_env {
    my ($iter_dir, $phase) = @_;
    script_run("free -h > $iter_dir/mem_$phase.log");
    script_run("df -h > $iter_dir/disk_$phase.log");
}

# Capture numeric resource metrics at the start of a run for correlation with
# the outcome: available memory (MB) and free space on the backing store (MB).
sub capture_metrics {
    my $mem = script_output(q(free -m | awk '/^Mem:/ {print $7}'), proceed_on_failure => 1);
    my $disk = script_output("df -m --output=avail $INST_DIR 2>/dev/null | tail -1", proceed_on_failure => 1);
    $mem =~ s/\D//g;
    $disk =~ s/\D//g;
    return ($mem || 0, $disk || 0);
}

# Deep, best-effort state capture taken only on a failing iteration. Failures
# are rare, so it is worth collecting the kernel/fs state at failure time to
# point at the root cause (memory fragmentation, slab growth, fs allocation).
sub capture_failure_state {
    my ($iter_dir, $fstype) = @_;
    my $out = "$iter_dir/failure_state";
    assert_script_run("mkdir -p $out");
    script_run("dmesg > $out/dmesg_live.log 2>&1");
    script_run("cp /proc/meminfo $out/ 2>/dev/null");
    script_run("cp /proc/slabinfo $out/ 2>/dev/null");
    script_run("cp /proc/buddyinfo $out/ 2>/dev/null");
    script_run("mount > $out/mounts.log 2>&1");
    script_run("losetup -a > $out/loop.log 2>&1");
    if ($fstype eq 'btrfs') {
        script_run("find /sys/fs/btrfs/*/allocation/ -type f -exec tail -n +1 {} + > $out/btrfs_alloc.log 2>&1");
    }
    elsif ($fstype eq 'xfs') {
        script_run("find /sys/fs/xfs/ -type f -exec tail -n +1 {} + > $out/xfs_stat.log 2>&1");
    }
    elsif ($fstype eq 'ext4') {
        script_run("find /sys/fs/ext4/ -type f -exec tail -n +1 {} + > $out/ext4_stat.log 2>&1");
    }
}

# Preserve the raw per-test logs xfstests writes under results/, before the next
# iteration overwrites them.
sub collect_iteration_logs {
    my ($category, $num, $iter_dir) = @_;
    for my $ext (qw(full out.bad dmesg)) {
        script_run("cp $INST_DIR/results/$category/$num.$ext $iter_dir/ 2>/dev/null");
    }
}

# Diff the first passing iteration against the first failing one. Uses a temp
# file instead of process substitution to stay POSIX-shell compatible. Returns
# the path of the generated diff file.
sub build_sporadic_diff {
    my ($dirname, $num, $pass_iter, $fail_iter) = @_;
    my $pass_dir = "$SPORADIC_DIR/$dirname/iter_$pass_iter";
    my $fail_dir = "$SPORADIC_DIR/$dirname/iter_$fail_iter";
    my $diff_file = "$SPORADIC_DIR/$dirname/diff_pass${pass_iter}_fail${fail_iter}.txt";
    my $pass_errors = "$SPORADIC_DIR/$dirname/.pass_errors";

    my @sections = (
        ["Test output ($num.full)", "$num.full"],
        ["Kernel messages ($num.dmesg)", "$num.dmesg"],
        ["Memory before test", 'mem_before.log'],
        ["Disk usage before test", 'disk_before.log'],
    );
    assert_script_run("true > $diff_file");
    for my $section (@sections) {
        my ($title, $file) = @$section;
        script_run("echo '=== $title ===' >> $diff_file");
        script_run("diff -u '$pass_dir/$file' '$fail_dir/$file' >> $diff_file 2>&1 || true");
        script_run("echo >> $diff_file");
    }

    # Error lines present only in the failing run.
    my $pattern = '(error|fail|warn|bug|assert)';
    script_run("echo '=== Error lines only in the failing run ===' >> $diff_file");
    script_run("grep -iE '$pattern' '$pass_dir/$num.full' 2>/dev/null > $pass_errors || true");
    script_run("grep -iE '$pattern' '$fail_dir/$num.full' 2>/dev/null | grep -vxF -f $pass_errors >> $diff_file 2>&1 || true");
    script_run("rm -f $pass_errors");
    return $diff_file;
}

# Summarise the loop outcome: pass rate, per-iteration table with resource
# metrics, average resources by outcome and, when the failure is reproduced
# sporadically, a diff between a passing and a failing iteration.
sub analyze_sporadic_results {
    my ($test_name, $iterations) = @_;
    my ($category, $num) = split(/\//, $test_name);
    (my $dirname = $test_name) =~ s/\//-/;
    my $total = scalar @$iterations;
    my $pass = grep { $_->{result} eq 'PASS' } @$iterations;
    my $fail = $total - $pass;
    my $pass_rate = $total ? sprintf("%.1f%%", $pass / $total * 100) : 'n/a';

    my $summary = "Test: $test_name (mode $SPORADIC_MODE)\n";
    $summary .= "Pass: $pass/$total ($pass_rate)   Fail: $fail/$total\n\n";

    # Per-iteration table: time series (spot failures clustering in time) plus
    # the resource metrics measured at each run start (spot resource pressure).
    $summary .= sprintf("%-5s %-9s %-6s %-7s %-13s %-13s\n",
        'iter', 'time', 'result', 'dur', 'mem_avail(MB)', 'inst_free(MB)');
    for my $it (@$iterations) {
        my $clock = substr(scalar(localtime($it->{timestamp})), 11, 8);
        $summary .= sprintf("[%2d]  %-9s %-6s %-7s %-13s %-13s\n",
            $it->{iter}, $clock, $it->{result}, "$it->{duration}s", $it->{mem_mb}, $it->{disk_mb});
    }

    # Correlation: compare average start-of-run resources between outcomes.
    my $avg = sub {
        my ($key, @rows) = @_;
        return 'n/a' unless @rows;
        my $sum = 0;
        $sum += $_->{$key} for @rows;
        return sprintf("%.0f", $sum / @rows);
    };
    my @passed = grep { $_->{result} eq 'PASS' } @$iterations;
    my @failed = grep { $_->{result} eq 'FAIL' } @$iterations;
    $summary .= "\nResource averages by outcome:\n";
    $summary .= sprintf("  PASS: mem_avail=%s MB  inst_free=%s MB\n", $avg->('mem_mb', @passed), $avg->('disk_mb', @passed));
    $summary .= sprintf("  FAIL: mem_avail=%s MB  inst_free=%s MB\n", $avg->('mem_mb', @failed), $avg->('disk_mb', @failed));

    if ($pass > 0 && $fail > 0) {
        my ($first_pass) = grep { $_->{result} eq 'PASS' } @$iterations;
        my ($first_fail) = grep { $_->{result} eq 'FAIL' } @$iterations;
        my $diff_file = build_sporadic_diff($dirname, $num, $first_pass->{iter}, $first_fail->{iter});
        $summary .= "\nSporadic failure reproduced. Diff (pass #$first_pass->{iter} vs fail #$first_fail->{iter}):\n";
        $summary .= script_output("head -n 100 $diff_file", proceed_on_failure => 1) . "\n";
        $summary .= "Full diff: $diff_file\n";
    }
    elsif ($fail == $total) {
        $summary .= "\nConsistently failing across all iterations (not sporadic).\n";
    }
    else {
        $summary .= "\nConsistently passing across all iterations (failure not reproduced).\n";
    }

    record_info("Sporadic result: $test_name", $summary);
}

# Loop a single flaky test in place, collecting per-iteration resource metrics,
# environment snapshots and logs, then analyse the outcome. The stop condition
# depends on DEBUG_SPORADIC_MODE:
#   fixed      - run exactly DEBUG_SPORADIC_LOOP times (statistics)
#   until_fail - stop at the first failure, up to DEBUG_SPORADIC_LOOP attempts
#   until_pass - loop until DEBUG_SPORADIC_LOOP consecutive passes, capped at
#                DEBUG_SPORADIC_MAX (confirm a fix)
sub run_sporadic_loop {
    my ($self, $test_name, $enable_heartbeat, $my_instance) = @_;
    my ($category, $num) = split(/\//, $test_name);
    (my $dirname = $test_name) =~ s/\//-/;
    my $test_dir = "$SPORADIC_DIR/$dirname";
    my $cap = ($SPORADIC_MODE eq 'until_pass') ? $SPORADIC_MAX : $SPORADIC_LOOP;

    assert_script_run("mkdir -p $test_dir");
    record_info("Sporadic: $test_name", "Mode $SPORADIC_MODE, up to $cap iterations");

    my @iterations;
    my $consecutive_pass = 0;
    for my $iteration (1 .. $cap) {
        my $iter_dir = "$test_dir/iter_$iteration";
        assert_script_run("mkdir -p $iter_dir");

        my ($mem_mb, $disk_mb) = capture_metrics();
        snapshot_env($iter_dir, 'before');
        my $start_time = time();
        my ($iter_status, $duration) = run_sporadic_once($self, $test_name, $enable_heartbeat, $my_instance);
        snapshot_env($iter_dir, 'after');
        collect_iteration_logs($category, $num, $iter_dir);

        my $result = ($iter_status =~ /PASSED/) ? 'PASS' : 'FAIL';
        capture_failure_state($iter_dir, $FSTYPE) if $result eq 'FAIL';
        push @iterations, {
            iter => $iteration, result => $result, duration => $duration,
            timestamp => $start_time, mem_mb => $mem_mb, disk_mb => $disk_mb,
        };
        log_add($STATUS_LOG, "$test_name.$iteration", $iter_status, $duration);
        record_info("Iter $iteration/$cap: $result", "$test_name -> $iter_status (${duration}s)");

        $consecutive_pass = ($result eq 'PASS') ? $consecutive_pass + 1 : 0;
        last if $SPORADIC_MODE eq 'until_fail' && $result eq 'FAIL';
        last if $SPORADIC_MODE eq 'until_pass' && $consecutive_pass >= $SPORADIC_LOOP;
    }

    analyze_sporadic_results($test_name, \@iterations);
}

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;
    (my $test = $args->{name}) =~ s/-/\//;
    my $enable_heartbeat = $args->{enable_heartbeat};
    my $is_last_one = $args->{last_one};

    # Sporadic debug: loop this test in place instead of running it once.
    if ($args->{sporadic}) {
        run_sporadic_loop($self, $test, $enable_heartbeat, $args->{my_instance});
        mutex_unlock 'last_subtest_run_finish' if $is_last_one;
        return;
    }

    umount_xfstests_dev($TEST_DEV, $SCRATCH_DEV, $SCRATCH_DEV_POOL) unless get_var('XFSTESTS_HIGHSPEED');
    my ($category, $num) = split(/\//, $test);
    my $status_log_content = "";
    my %targs = (name => $test, status => 'FAILED', time => 'timeout');

    $self->{targs} = \%targs;
    $self->{result_args} = {status => 'FAILED', time => 'timeout'};

    $whitelist_env->{kernel} = script_output('uname -r');
    $whitelist_env->{libc} = script_output('rpm -q glibc');
    $whitelist_env->{ltp_version} = script_output('rpm -q xfstests');
    enter_cmd("echo $test > /dev/$serialdev");
    if ($enable_heartbeat == 0) {
        $self->{result_args} = test_run_without_heartbeat($self, $test, $TIMEOUT_NO_HEARTBEAT, $FSTYPE, $RAW_DUMP, $SCRATCH_DEV, $SCRATCH_DEV_POOL, $XFSTESTS_DEEP_CLEAN, $INJECT_INFO, $LOOP_DEVICE, $ENABLE_KDUMP, $VIRTIO_CONSOLE, 0, $args->{my_instance});
        $status = $self->{result_args}->{status};
        $time = $self->{result_args}->{time};
        $status_log_content = $self->{result_args}->{output};
        $test_timeout = $self->{result_args}->{timeout};
    }
    else {
        my $result_args = {};
        heartbeat_start;
        test_run($test, $FSTYPE, $XFSTESTS_DEEP_CLEAN, $INJECT_INFO);
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
            # Heartbeat lost: the SUT crashed or hung. Recover it (reboot, save
            # kdump, reload loop devices) before continuing with the next subtest.
            recover_after_crash($self, $test, $FSTYPE, $ENABLE_KDUMP, $args->{my_instance});
            # Add test status to STATUS_LOG file
            log_add($STATUS_LOG, $test, $status, $time);
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

        # Knowledge base suggestion for immediate feedback on failure
        eval {
            if (init_kb()) {
                my $kb_result = analyze_by_knowledgebase($test, $FSTYPE, $targs{output}, $targs{fullog});
                if ($kb_result) {
                    record_info("AI:$test", format_analysis_result($kb_result));
                }
            }
        };
        bmwqemu::fctinfo("Knowledge base analysis error for $test: $@") if $@;
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
