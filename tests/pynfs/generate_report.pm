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
    my $folder = get_required_var('PYNFS');

    assert_script_run("cd ~/pynfs/$folder");

    upload_logs('result-raw.txt', failok => 1);

    script_run('../showresults.py result-raw.txt > result-analysis.txt');
    upload_logs('result-analysis.txt', failok => 1);

    script_run('grep -A 2 FAILURE result-analysis.txt | grep -v PASS > result-fail.txt');
    upload_logs('result-fail.txt', failok => 1);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    upload_log();
    upload_system_logs();
}

1;
