package consoletest;
use base "opensusebasetest";

use strict;
use warnings;
use testapi;
use known_bugs;

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
    $self->export_basic_logs;
}

1;
