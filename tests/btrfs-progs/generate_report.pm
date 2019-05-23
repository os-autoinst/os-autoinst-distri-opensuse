# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Upload logs and generate junit report
# Maintainer: An Long <lan@suse.com>
package generate_report;

use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use ctcs2_to_junit;
use upload_system_log;

my $STATUS_LOG = '/opt/status.log';
my $JUNIT_FILE = '/opt/output.xml';

sub log_end {
    my $file = shift;
    my $cmd  = "echo 'Test run complete' >> $file";
    type_string("\n");
    assert_script_run($cmd);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Finalize status log and upload it
    log_end($STATUS_LOG);
    upload_logs($STATUS_LOG, timeout => 60, log_name => "test");

    #upload system log
    upload_system_logs();

    # Junit xml report
    my $script_output = script_output("cat $STATUS_LOG", 600);
    my $tc_result     = analyzeResult($script_output);
    my $xml           = generateXML($tc_result);
    assert_script_run("echo \'$xml\' > $JUNIT_FILE", 7200);
    parse_junit_log($JUNIT_FILE);
}

1;
