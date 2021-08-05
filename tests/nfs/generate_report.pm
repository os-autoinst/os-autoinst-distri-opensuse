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

sub upload_pynfs_log {
    my $self   = shift;
    my $folder = get_required_var('PYNFS');

    assert_script_run("cd ~/pynfs/$folder");

    upload_logs('result-raw.txt', failok => 1);

    script_run('../showresults.py result-raw.txt > result-analysis.txt');
    upload_logs('result-analysis.txt', failok => 1);

    script_run('../showresults.py --hidepass result-raw.txt > result-fail.txt');
    upload_logs('result-fail.txt', failok => 1);

    if (script_run('[ -s result-fail.txt ]') == 0) {
        $self->result("fail");
        record_info("failed tests", script_output('cat result-fail.txt'), result => 'fail');
    }
}

sub upload_cthon04_log {
    my $self = shift;
    assert_script_run('cd ~/cthon04');
    if (script_output("grep 'All tests completed' ./result* | wc -l") =~ '4') {
        record_info('All tests completed');
    }
    else {
        $self->result("fail");
        record_info("Test fail: Not all test completed");
    }
    if (script_output("grep ' ok.' ./result_basic_test.txt | wc -l") =~ '9') {
        record_info('Basic test pass');
    }
    else {
        $self->result("fail");
        record_info('Basic test failed');
    }
    if (script_output("egrep ' ok|success' ./result_special_test.txt | wc -l") =~ '7') {
        record_info('Special test pass');
    }
    else {
        $self->result("fail");
        record_info('Special test failed');
    }
    if (script_run("grep 'Congratulations, you passed the locking tests!' ./result_lock_test.txt")) {
        $self->result("fail");
        record_info('Lock test failed');
    }
    upload_logs('result_*', failok => 1);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    if (get_var("PYNFS")) {
        $self->upload_pynfs_log();
    }
    elsif (get_var("CTHON04")) {
        $self->upload_cthon04_log();
    }
    upload_system_logs();
}

1;
