## no critic (RequireFilenameMatchesPackage);
package x11test;
use base "opensusebasetest";

# Base class for all openSUSE tests

use strict;
use testapi;

sub post_fail_hook() {
    my ($self) = shift;
    $self->export_kde_logs;
    $self->export_logs;

    save_screenshot;
}

sub post_run_hook {
    my ($self) = @_;

    assert_screen('generic-desktop');
}

1;
# vim: set sw=4 et:
