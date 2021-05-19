# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Upload logs and generate report
# Maintainer: Yong Sun <yosun@suse.com>
package generate_report;

use strict;
use warnings;
use base 'opensusebasetest';
use File::Basename;
use testapi;
use upload_system_log;

sub upload_log {
    my $log_file = "./log.txt";
    my $timeout  = 90;
    my $folder   = get_required_var('PYNFS');
    assert_script_run("cd ~/pynfs/$folder");

    #show failures and save to log
    script_run('../nfs4.0/showresults.py log.txt | grep -A 2 FAILURE | grep -v PASS | tee fails.txt');
    upload_logs('fails.txt', timeout => $timeout, log_name => 'upload-failure');

    #raw log
    upload_logs($log_file, timeout => $timeout, log_name => 'upload-raw');

    #analys log
    script_run('./showresults.py log.txt > result.txt');
    upload_logs('result.txt', timeout => $timeout, log_name => 'upload-analys');
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    upload_log();
    upload_system_logs();
}

1;
