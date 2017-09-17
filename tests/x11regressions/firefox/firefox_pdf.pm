# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox PDF reader test (Case#1436081)
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox;

    send_key "esc";
    send_key "alt-d";
    type_string "http://www.gnupg.org/gph/en/manual.pdf\n";
    $self->firefox_check_popups;

    assert_screen('firefox-pdf-load', 90);

    sleep 1;
    for my $i (1 .. 2) { assert_and_click 'firefox-pdf-zoom_out_button'; }
    assert_screen('firefox-pdf-zoom_out');

    send_key "tab";
    for my $i (1 .. 4) { assert_and_click 'firefox-pdf-zoom_in_button'; }
    assert_screen('firefox-pdf-zoom_in');

    assert_and_click 'firefox-pdf-zoom_menu';
    sleep 1;
    assert_and_click 'firefox-pdf-zoom_menu_actual_size';    #"Actual Size"
    assert_screen('firefox-pdf-actual_size');

    sleep 1;
    assert_and_click 'firefox-pdf-icon_fullscreen';          #Full Screen

    send_key "esc";
    sleep 1;
    assert_and_click "firefox-pdf-actual_size";
    assert_and_click "firefox-pdf-page";
    sleep 1;
    send_key "3";
    send_key "ret";
    sleep 1;
    assert_screen('firefox-pdf-pagedown');

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
