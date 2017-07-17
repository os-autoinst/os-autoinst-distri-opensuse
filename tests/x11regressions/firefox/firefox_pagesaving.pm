# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436102: Firefox: Page Saving
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox;

    send_key "esc";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "http://www.mozilla.org/en-US\n";

    assert_screen('firefox-pagesaving-load', 90);

    send_key "ctrl-s";
    assert_screen 'firefox-pagesaving-saveas';

    send_key "alt-s";
    sleep 5;

    # Exit
    $self->exit_firefox;

    x11_start_program("xterm");
    send_key "ctrl-l";
    wait_still_screen 3;
    type_string "ls Downloads/\n";
    assert_screen 'firefox-pagesaving-downloads';
    assert_script_run 'rm -rf Downloads/*';
    send_key "ctrl-d";
}
1;
# vim: set sw=4 et:
