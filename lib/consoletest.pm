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

1;
# vim: set sw=4 et:
