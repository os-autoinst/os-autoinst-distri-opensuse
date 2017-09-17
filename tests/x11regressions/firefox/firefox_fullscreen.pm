# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Case#1479413: Firefox: Full Screen Browsing

# Summary: Case#1479413: Firefox: Full Screen Browsing
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
    type_string "file:///usr/share/w3m/w3mhelp.html\n";
    $self->firefox_check_popups;
    assert_screen('firefox-fullscreen-page', 90);

    send_key "f11";
    assert_screen('firefox-fullscreen-enter', 90);

    sleep 1;
    send_key "f11";
    assert_screen('firefox-fullscreen-page', 90);

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
