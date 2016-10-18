# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1479522: Firefox: Web Developer Tools
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {

    my ($self) = @_;
    $self->start_firefox;

    send_key "esc";
    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "opensuse.org\n";
    assert_screen('firefox-developertool-opensuse', 90);

    sleep 2;
    send_key "ctrl-shift-i";
    assert_screen('firefox-developertool-gerneral', 30);
    sleep 2;
    assert_and_click "firefox-developertool-click_element";
    sleep 1;
    assert_and_click "firefox-developertool-check_element";

    sleep 2;
    assert_screen("firefox-developertool-element", 30);

    sleep 1;
    assert_and_click "firefox-developertool-console_button";
    sleep 1;
    send_key "f5";
    assert_screen("firefox-developertool-console_contents", 30);

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
