package consoletest;
use base "opensusebasetest";

use strict;
use testapi;

# Base class for all openSUSE console tests

sub post_run_hook {
    my ($self) = @_;

    # start next test in home directory
    type_string "cd\n";

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    # Export logs after failure
    script_run "journalctl --no-pager -b 0 > /tmp/full_journal.log";
    upload_logs "/tmp/full_journal.log";
}

1;
# vim: set sw=4 et:
