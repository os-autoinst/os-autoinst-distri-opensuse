# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Upload logs and generate junit report
# - Get xfs status.log from datadir
# - End log and upload logs (and all subdirs)
# - Upload kdump logs unless NO_KDUMP is set to 1
# - Upload system logs
# - Parse /opt/status.log for PASSED/FAILED/SKIPPED
# - Generate XML file using parsed results from previous step
# - Upload XML file for analysis by OpenQA::Parser
# Maintainer: Yong Sun <yosun@suse.com>

## no os-autoinst style

package generate_report;

use 5.018;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use serial_terminal 'select_serial_terminal';
use upload_system_log;
use Utils::Logging 'save_ulog';
use xfstests_utils 'get_status_log_content';

my $STATUS_LOG = '/opt/status.log';
my $LOG_DIR = '/opt/log';
my $KDUMP_DIR = '/opt/kdump';
my $JUNIT_FILE = '/opt/output.xml';

sub log_end {
    my $file = shift;
    my $cmd = "echo 'Test run complete' >> $file";
    send_key 'ret';
    script_run($cmd, proceed_on_failure => 1);
}

# Compress all sub directories under $dir and upload them.
sub upload_subdirs {
    my ($dir, $timeout) = @_;
    my $output = script_output("if [ -d $dir ]; then find $dir -maxdepth 1 -mindepth 1 -type f -or -type d; else echo $dir folder not exist; fi");
    if ($output =~ /folder not exist/) { return; }
    for my $subdir (split(/\n/, $output)) {
        next if ($subdir =~ /subtest_result_num/);
        my $tarball = "$subdir.tar.xz";
        assert_script_run("ll; tar cJf $tarball -C $dir " . basename($subdir), $timeout);
        upload_logs($tarball, timeout => $timeout);
    }
}

sub test_summary {
    my ($text) = @_;
    my $test_num = 0;
    my $pass_num = 0;
    my $fail_num = 0;
    my $skip_num = 0;
    my $total_time = 0;
    my $test_range = '';
    foreach (split("\n", $text)) {
        my ($test_name, $test_status, $test_time);
        if ($_ =~ /(\S+)\s+\.{3}\s+\.{3}\s+(PASSED|FAILED|SKIPPED)\s+\((\S+)\)/g) {
            $test_name = $1;
            $test_status = $2;
            $test_time = $3;
        }
        else {
            next;
        }
        (my $generate_name = $test_name) =~ s/-/\//;
        $test_num += 1;
        $test_range = $test_range . $generate_name . " ... ... " . $test_status . " ($test_time seconds)" . "\n";
        if ($test_status =~ /FAILED/) {
            $fail_num += 1;
        }
        elsif ($test_status =~ /SKIPPED/) {
            $skip_num += 1;
        }
        else {
            $pass_num += 1;
        }
        $total_time += $test_time;
    }
    record_info('Summary', "Test number: $test_num\nPass: $pass_num\nSkip: $skip_num\nFail: $fail_num\nTotal time: $total_time seconds\n");
    record_info('Test Ranges', "$test_range");
}

sub run {
    select_serial_terminal;
    return if get_var('XFSTESTS_NFS_SERVER');
    sleep 5;

    # Recover status log after snapshot rollback. Worker-side buffer
    # survives VM rollbacks; save it directly on the worker via save_ulog.
    my $log_line = int(script_output("cat $STATUS_LOG 2>/dev/null | wc -l", 60, proceed_on_failure => 1));
    my $recovered_log;
    if ($log_line < 2) {
        $recovered_log = get_status_log_content();
        save_ulog($recovered_log, 'status.log') if $recovered_log;
    }

    # Reload test logs if check missing
    script_run("if [ ! -d $LOG_DIR ]; then mkdir -p $LOG_DIR; timeout 20 curl -O " . autoinst_url . '/files/opt_logs.tar.gz; tar zxvfP opt_logs.tar.gz; fi');

    # Finalize status log and upload it
    log_end($STATUS_LOG);
    upload_logs($STATUS_LOG, timeout => 60, log_name => $STATUS_LOG);
    upload_subdirs($LOG_DIR, 1200);

    # Upload kdump logs if not set "NO_KDUMP=1"
    unless (check_var('NO_KDUMP', '1')) {
        upload_subdirs($KDUMP_DIR, 1200);
    }

    # Upload system log
    upload_system_logs();

    # Summary: use recovered worker-side log if SUT copy was lost
    my $status_content = $recovered_log // script_output("cat $STATUS_LOG", 600);
    test_summary($status_content);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
