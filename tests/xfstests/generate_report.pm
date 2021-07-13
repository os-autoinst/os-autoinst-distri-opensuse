# SUSE's openQA tests
#
# Copyright © 2018-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Upload logs and generate junit report
# - Get xfs status.log from datadir
# - End log and upload logs (and all subdirs)
# - Upload kdump logs unless NO_KDUMP is set
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
use ctcs2_to_junit;
use upload_system_log;

my $STATUS_LOG = '/opt/status.log';
my $LOG_DIR    = '/opt/log';
my $KDUMP_DIR  = '/opt/kdump';
my $JUNIT_FILE = '/opt/output.xml';

# Compress all sub directories under $dir and upload them.
sub upload_subdirs {
    my ($dir, $timeout) = @_;
    my $output = script_output("if [ -d $dir ]; then find $dir -maxdepth 1 -mindepth 1 -type f -or -type d; else echo $dir folder not exist; fi");
    if ($output =~ /folder not exist/) { return; }
    for my $subdir (split(/\n/, $output)) {
        my $tarball = "$subdir.tar.xz";
        assert_script_run("ll; tar cJf $tarball -C $dir " . basename($subdir), $timeout);
        upload_logs($tarball, timeout => $timeout, log_name => basename($dir));
    }
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    upload_logs($STATUS_LOG, timeout => 60, log_name => "test");

    # Upload test logs
    upload_subdirs($LOG_DIR, 1200);

    # Upload kdump logs if not set "NO_KDUMP"
    unless (get_var('NO_KDUMP')) {
        upload_subdirs($KDUMP_DIR, 1200);
    }

    #upload system log
    upload_system_logs();

    # Junit xml report
    my $script_output = script_output("cat $STATUS_LOG");
    my $tc_result     = analyzeResult($script_output);
    my $xml           = generateXML($tc_result);
    script_output("echo \'$xml\' > $JUNIT_FILE");
    parse_junit_log($JUNIT_FILE);
}

1;
