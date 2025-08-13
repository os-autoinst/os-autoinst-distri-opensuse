# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Show the testresults of a job
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base "x11test";
use testapi;

sub upload_autoinst_log {
    assert_script_run 'openqa-cli api -X post jobs/1/cancel';
    for my $i (1 .. 10) {
        # wait for test to finish and upload
        last if (script_run('openqa-cli api --pretty jobs/1 | grep state | grep done', 40) == 0);
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

sub run {
    assert_screen 'openqa-tests';
    assert_and_click 'openqa-tests';
    # At this point the openQA job might still be running or already finished.
    # Ensure to show finished results at the bottom of the screen whenever the
    # page finished loading
    send_key_until_needlematch 'openqa-job-minimalx', 'up';
    click_lastmatch;
    assert_and_click('openqa-job-details', timeout => 60);
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
