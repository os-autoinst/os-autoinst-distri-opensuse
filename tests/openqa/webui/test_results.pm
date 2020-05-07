# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Show the testresults of a job
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "x11test";
use testapi;

sub upload_autoinst_log {
    assert_script_run 'openqa-client jobs/1/cancel post';
    for my $i (1 .. 10) {
        # wait for test to finish and upload
        last if (script_run('openqa-client jobs/1 | grep state | grep done', 40) == 0);
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
    # get rid of that horrible tutorial box
    wait_still_screen;
    assert_and_click 'openqa-dont-notify-me';
    assert_and_click 'openqa-tutorial-confirm';
    assert_screen 'openqa-tutorial-closed';
    wait_still_screen;

    # while job not finished
    for (1 .. 5) {
        send_key 'pgup';
        assert_and_click 'openqa-tests';
        wait_still_screen;
        last if check_screen 'openqa-job-minimalx', 2;
        send_key 'pgdn';
        last if check_screen 'openqa-job-minimalx', 2;
    }
    assert_and_click 'openqa-job-minimalx';

    # Do not hit 'f5' too early
    wait_still_screen;

    # wait for result
    for (1 .. 25) {
        send_key 'f5';
        wait_still_screen;
        send_key 'home';
        assert_and_click 'openqa-job-details';
        wait_still_screen;
        last if check_screen('openqa-testresult', 60);
    }
    assert_screen 'openqa-testresult';
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
