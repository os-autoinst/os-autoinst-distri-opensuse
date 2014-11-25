package consoletest;
use base "opensusebasetest";

# Base class for all openSUSE tests

use testapi ();

sub post_run_hook {
    my ($self) = @_;

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

1;
# vim: set sw=4 et:
