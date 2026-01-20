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
package generate_report;

use 5.018;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use serial_terminal 'select_serial_terminal';
use upload_system_log;

my $STATUS_LOG = '/opt/status.log';
my $LOG_DIR = '/opt/log';
my $KDUMP_DIR = '/opt/kdump';
my $JUNIT_FILE = '/opt/output.xml';

sub log_end {
    my $file = shift;
    my $cmd = "echo 'Test run complete' >> $file";
    send_key 'ret';
    script_run($cmd, timeout => 0);
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

    # Reload uploaded status log back to file
    my $log_line = int(script_output("cat $STATUS_LOG | wc -l"));
    if ($log_line < 2) {
        script_run('df -h; timeout 20 curl -O ' . autoinst_url . "/files/status.log; cat status.log > $STATUS_LOG");
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

    # Summary test range info
    my $script_output = script_output("cat $STATUS_LOG", 600);
    test_summary($script_output);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
