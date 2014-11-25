package x11test;
use base "opensusebasetest";

# Base class for all openSUSE tests

use testapi ();

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
