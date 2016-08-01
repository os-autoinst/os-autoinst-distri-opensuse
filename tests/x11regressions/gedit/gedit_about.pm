# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

# Case 1436120 - Gedit: help about
sub run() {
    my $self = shift;
    x11_start_program("gedit");

    # check about window
    wait_screen_change {
        send_key "alt-h";
    };
    send_key "a";
    assert_screen 'gedit-help-about';

    # check license
    assert_screen 'gedit-about-license';

    # check website link
    assert_and_click 'gedit-about-link';
    # give a little time to open and load website
    assert_screen 'gedit-open-firefox', 60;
    wait_screen_change {
        send_key "ctrl-q";
    };

    # check credits
    send_key "alt-r";
    assert_screen 'gedit-about-credits';
    send_key "alt-r";    # close credit

    assert_screen 'gedit-about-license';
    send_key "alt-c";    # close about
    assert_screen 'gedit-launched';
    send_key "ctrl-q";
}

1;
# vim: set sw=4 et:
