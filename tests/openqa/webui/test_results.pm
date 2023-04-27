# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Show the testresults of a job
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "x11test";
use testapi;


my $tutorial_disabled;

sub upload_autoinst_log {
    assert_script_run 'openqa-cli api -X post jobs/1/cancel';
    for my $i (1 .. 10) {
        # wait for test to finish and upload
        last if (script_run('openqa-cli api jobs/1 | grep state | grep done', 40) == 0);
        sleep 5;
    }
    if (script_run('wget http://localhost/tests/1/file/autoinst-log.txt') != 0) {
        record_info('Log download', 'Error downloading autoinst-log.txt from nested openQA webui. Consult journal for further information.', result => 'fail');
        script_run 'find /var/lib/openqa/testresults/';
    }
    else {
        upload_logs('autoinst-log.txt', log_name => "nested");
    }
}

sub handle_notify_popup {
    assert_screen 'openqa-dont-notify-me';
    for my $i (1 .. 5) {
        assert_and_click 'openqa-dont-notify-me';
        if (check_screen('openqa-tutorial-confirm', 15)) {
            last;
        }
    }
    assert_and_click 'openqa-tutorial-confirm';
    assert_screen 'openqa-tutorial-closed';
}

sub run {
    handle_notify_popup;
    assert_screen 'openqa-tests';
    assert_and_click 'openqa-tests';
    assert_and_click 'openqa-job-minimalx';
    assert_and_click 'openqa-job-details';
    assert_screen 'openqa-testresult', 600;
}

sub test_flags {
    return {fatal => 1};
}

sub post_run_hook {
    # do not assert generic desktop

    select_console 'root-console';
    upload_autoinst_log;
}

sub post_fail_hook {
    my ($self) = @_;
    select_console 'log-console';
    upload_autoinst_log;
    $self->SUPER::post_fail_hook;
}

1;
