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

use strict;
use 5.018;
use warnings;
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
    my $cmd = "echo '\nTest run complete' >> $file";
    send_key 'ret';
    script_run($cmd, proceed_on_failure => 1);
}

# Compress all sub directories under $dir and upload them.
sub upload_subdirs {
    my ($dir, $timeout) = @_;
    my $output = script_output("if [ -d $dir ]; then find $dir -maxdepth 1 -mindepth 1 -type f -or -type d; else echo $dir folder not exist; fi");
    if ($output =~ /folder not exist/) { return; }
    for my $subdir (split(/\n/, $output)) {
        my $tarball = "$subdir.tar.xz";
        assert_script_run("ll; tar cJf $tarball -C $dir " . basename($subdir), $timeout);
        upload_logs($tarball, timeout => $timeout);
    }
}

sub analyze_result {
    my ($text) = @_;
    my $test_num = 0;
    my $pass_num = 0;
    my $fail_num = 0;
    my $skip_num = 0;
    my $total_time = 0;
    my $test_range = '';
    foreach (split("\n", $text)) {
        if ($_ =~ /(\S+)\s+\.{3}\s+\.{3}\s+(PASSED|FAILED|SKIPPED)\s+\((\S+)\)/g) {
            my $test_name = $1;
            my $test_status = $2;
            my $test_time = $3;
            (my $test_path = $test_name) =~ s/-/\//;
            $test_num += 1;
            $test_range = $test_range . $test_path . " ... ... " . $test_status . " ($test_time seconds)" . "\n";
            $test_path = '/opt/log/' . $test_path;
            bmwqemu::fctinfo("$test_name");
            if ($test_status =~ /FAILED|SKIPPED/) {
                my $test_out_content = script_output("if [ -f $test_path ]; then tail -n 200 $test_path | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; else echo 'No log in test path, find log in serial0.txt'; fi", 600);
                my $test_out_bad = '';
                my $test_full_log = '';
                my $test_dmesg = '';
                if ($test_status =~ /FAILED/) {
                    $test_out_bad = script_output("if [ -f $test_path.out.bad ]; then tail -n 200 $test_path.out.bad | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; else echo '$test_path.out.bad not exist';fi", 600);
                    $test_full_log = script_output("if [ -f $test_path.full ]; then tail -n 200 $test_path.full | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; else echo '$test_path.full not exist'; fi", 600);
                    $test_dmesg = script_output("if [ -f $test_path.dmesg ]; then tail -n 200 $test_path.dmesg | sed \"s/'//g\" | tr -cd '\\11\\12\\15\\40-\\176'; fi", 600);
                    $fail_num += 1;
                }
                else {
                    $skip_num += 1;
                }
                # show fail message
                my $targs = OpenQA::Test::RunArgs->new();
                $targs->{name} = $test_name;
                $targs->{time} = $test_time;
                $targs->{status} = $test_status;
                $targs->{output} = $test_out_content;
                if ($test_status =~ /FAILED/) {
                    $targs->{outbad} = $test_out_bad;
                    $targs->{fullog} = $test_full_log;
                    $targs->{dmesg} = $test_dmesg;
                }
                autotest::loadtest("tests/xfstests/xfstests_failed.pm", name => $test_name, run_args => $targs);
            }
            else {
                $pass_num += 1;
            }
            $total_time += $test_time;
        }
    }
    record_info('Summary', "Test number: $test_num\nPass: $pass_num\nSkip: $skip_num\nFail: $fail_num\nTotal time: $total_time seconds\n");
    record_info('Test Ranges', "$test_range");
}

sub run {
    select_serial_terminal;
    return if get_var('XFSTESTS_NFS_SERVER');
    sleep 5;

    # Reload uploaded status log back to file
    script_run('df -h; curl -O ' . autoinst_url . "/files/status.log; cat status.log > $STATUS_LOG", die_on_timeout => 0);

    # Reload test logs if check missing
    script_run("if [ ! -d $LOG_DIR ]; then mkdir -p $LOG_DIR; curl -O " . autoinst_url . '/files/opt_logs.tar.gz; tar zxvfP opt_logs.tar.gz; fi', die_on_timeout => 0);

    # Finalize status log and upload it
    log_end($STATUS_LOG);
    upload_logs($STATUS_LOG, timeout => 60, log_name => $STATUS_LOG);

    # Upload test logs
    upload_subdirs($LOG_DIR, 1200);

    # Upload kdump logs if not set "NO_KDUMP=1"
    unless (check_var('NO_KDUMP', '1')) {
        upload_subdirs($KDUMP_DIR, 1200);
    }

    #upload system log
    upload_system_logs();

    # Junit xml report
    my $script_output = script_output("cat $STATUS_LOG", 600);
    analyze_result($script_output);
}

sub test_flags {
    return {no_rollback => 1};
}

1;
