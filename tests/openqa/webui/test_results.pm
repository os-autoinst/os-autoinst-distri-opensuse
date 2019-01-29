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
use base "x11test";
use testapi;

sub upload_autoinst_log {
    assert_script_run 'wget http://localhost/tests/1/file/autoinst-log.txt';
    upload_logs('autoinst-log.txt', log_name => "nested");
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

    # wait for result
    if (!check_screen('openqa-testresult', 300)) {
        send_key 'f5';
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
