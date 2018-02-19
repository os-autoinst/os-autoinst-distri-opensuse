## no critic (RequireFilenameMatchesPackage);
package sles4sap;
use base "opensusebasetest";

use strict;
use testapi;
use utils;

our $prev_console;

sub pre_run_hook {
    my ($self) = @_;

    $prev_console = $testapi::selected_console;
}

sub post_run_hook {
    my ($self) = @_;

    return unless ($prev_console);
    select_console($prev_console, await_console => 0);
    ensure_unlocked_desktop if ($prev_console eq 'x11');
}

1;
# vim: set sw=4 et:
