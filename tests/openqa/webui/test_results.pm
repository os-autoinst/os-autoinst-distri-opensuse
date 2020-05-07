# SUSE's openQA tests
#
# Copyright © 2018-2020 SUSE LLC
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


my $tutorial_disabled;

sub with_optional_tutorial_popup { [grep { $_ ne '' } (@_, $tutorial_disabled ? '' : 'openqa-dont-notify-me')] }

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

sub handle_notify_popup {
    return undef unless match_has_tag 'openqa-dont-notify-me';
    assert_and_click 'openqa-tutorial-confirm';
    assert_screen 'openqa-tutorial-closed';
    $tutorial_disabled = 1;
    return 1;
}

sub run {
    # get rid of the tutorial box which can pop up immediately or slightly
    # delayed when we already went to the test list and go to the test details
    # of the running job
    $tutorial_disabled = 0;
    assert_screen with_optional_tutorial_popup 'openqa-tests';
    click_lastmatch;
    handle_notify_popup and assert_and_click 'openqa-tests';
    assert_screen with_optional_tutorial_popup 'openqa-job-minimalx';
    click_lastmatch;
    handle_notify_popup and assert_and_click 'openqa-job-minimalx';
    assert_screen with_optional_tutorial_popup 'openqa-job-details';
    click_lastmatch;
    handle_notify_popup;
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
