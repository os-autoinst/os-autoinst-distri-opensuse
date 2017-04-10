# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Online migration setup
# Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    my ($self) = @_;
    $self->setup_online_migration;
}

sub test_flags() {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = @_;

    # Show the console log if stuck on the plymouth splash screen
    wait_screen_change {
        send_key 'esc';
    };

    # Try to login to tty console
    select_console 'root-console' unless (match_has_tag('emergency-shell') or match_has_tag('emergency-mode'));

    # Save logs if succeed to access a console
    $self->SUPER::post_fail_hook;
}

1;
# vim: set sw=4 et:
