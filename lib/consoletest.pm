package consoletest;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;

# Base class for all console tests

sub post_run_hook {
    my ($self) = @_;

    # start next test in home directory
    type_string "cd\n";

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;
    $self->remount_tmp_if_ro;
    # Export logs after failure
    assert_script_run("journalctl --no-pager -b 0 > /tmp/full_journal.log");
    upload_logs "/tmp/full_journal.log";
    assert_script_run("dmesg > /tmp/dmesg.log");
    upload_logs "/tmp/dmesg.log";
}

1;
