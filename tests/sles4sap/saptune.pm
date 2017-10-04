# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: saptune availability and basic commands to the tuned daemon
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    my ($self) = @_;

    x11_start_program('xterm');
    assert_screen('xterm');

    script_sudo("saptune daemon status");
    assert_screen 'saptune-tuned-daemon-is-running', 10;

    type_string "clear\n";
    assert_script_sudo("saptune daemon stop");
    script_sudo("saptune daemon status");
    assert_screen 'saptune-tuned-daemon-is-stopped', 10;
    die "Command 'saptune daemon stop' couldn't stop tuned" unless match_has_tag "saptune-tuned-daemon-is-stopped";

    type_string "clear\n";
    assert_script_sudo("saptune daemon start");
    script_sudo("saptune daemon status");
    assert_screen 'saptune-tuned-daemon-is-running', 10;
    die "Command 'saptune daemon start' couldn't start tuned" unless match_has_tag "saptune-tuned-daemon-is-running";

    type_string "clear\n";
    assert_script_sudo("saptune solution list");
    assert_screen 'saptune-solution-list', 10;
    die "Command 'saptune solution list' output is not recognized" unless match_has_tag "saptune-solution-list";

    type_string "clear\n";
    assert_script_sudo("saptune note list");
    assert_screen 'saptune-note-list', 10;
    die "Command 'saptune note list' output is not recognized" unless match_has_tag "saptune-note-list";

    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
