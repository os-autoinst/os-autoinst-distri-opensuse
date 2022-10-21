# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Upload logs and generate junit report
# Maintainer: An Long <lan@suse.com>
use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use serial_terminal 'select_serial_terminal';
use ctcs2_to_junit;
use upload_system_log;

use constant STATUS_LOG => '/opt/status.log';
use constant LOG_DIR => '/opt/logs/';
use constant JUNIT_FILE => '/opt/output.xml';

sub log_end {
    my $file = shift;
    my $cmd = "echo 'Test run complete' >> $file";
    send_key 'ret';
    assert_script_run($cmd);
}

# Compress the directory and upload tarball.
sub upload_tarball {
    my $dir = shift;
    my $timeout = shift || 90;
    my $output = script_output("if [ -d $dir ]; then basename $dir; else echo $dir folder not exist; fi");
    if ($output =~ /folder not exist/) { return; }
    my $tarball = "/opt/$output.tar.xz";
    assert_script_run("tar cJf $tarball -C " . dirname($dir) . " " . basename($dir), $timeout);
    upload_logs($tarball, timeout => $timeout);
}

sub run {
    select_serial_terminal;

    # Finalize status log and upload it
    log_end STATUS_LOG;
    upload_logs(STATUS_LOG, log_name => STATUS_LOG);

    # Upload test logs
    upload_tarball LOG_DIR;

    #upload system log
    upload_system_logs();

    # Junit xml report
    my $script_output = script_output('cat ' . STATUS_LOG);
    my $tc_result = analyzeResult($script_output);
    my $xml = generateXML($tc_result);
    assert_script_run("echo \'$xml\' > " . JUNIT_FILE);
    parse_junit_log JUNIT_FILE;

    record_soft_failure "poo#110137 - Mark SKIPPED as soft failure" if check_var('SOFT_FAILURE', 1);
}

1;
