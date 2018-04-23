# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Upload logs and generate junit report
# Maintainer: Nathan Zhao <jtzhao@suse.com>
package generate_report;

use strict;
use 5.018;
use warnings;
use base "opensusebasetest";
use testapi;
use ctcs2_to_junit;

my $LOG_FILE   = "/tmp/xfstests.log";
my $JUNIT_FILE = "/tmp/output.xml";

sub log_end {
    my $file = shift;
    my $cmd  = "echo 'Test run complete' >> $file";
    type_string("\n");
    assert_script_run($cmd);
}

sub run {
    my $self = shift;
    my ($filesystem, $category) = split(/-/, get_var("XFSTESTS"));
    select_console('root-console');

    # Finalize log file
    log_end($LOG_FILE);

    # Upload logs
    upload_logs($LOG_FILE, timeout => 60);
    assert_script_run("tar cJf /tmp/$category.tar.xz -C /tmp $category");
    upload_logs("/tmp/$category.tar.xz", timeout => 120);

    # Junit xml report
    my $script_output = script_output("cat $LOG_FILE");
    my $tc_result     = analyzeResult($script_output);
    my $xml           = generateXML($tc_result);
    assert_script_run("echo \'$xml\' > $JUNIT_FILE", 7200);
    parse_junit_log($JUNIT_FILE);
}

1;
