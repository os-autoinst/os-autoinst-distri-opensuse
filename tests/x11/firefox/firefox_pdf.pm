# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaFirefox
# Summary: Firefox PDF reader test (Case#1436081)
# - Launch xterm, kill firefox, cleanup previous firefox configuration, launch
# firefox
# - Open "http://www.gnupg.org/gph/en/manual.pdf"
# - Click on zoom out button
# - Click on zoom in button
# - Access zoom menu and select "Actual size"
# - Jump to page 3
# - Exit firefox
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use warnings;
use base "x11test";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox_with_profile;
    $self->firefox_open_url('http://www.gnupg.org/gph/en/manual.pdf', assert_loaded_url => 'firefox-pdf-load');

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

    assert_and_click "firefox-pdf-page";
    sleep 1;
    send_key "3";
    send_key "ret";
    sleep 1;
    assert_screen('firefox-pdf-pagedown');

    $self->exit_firefox;
}
1;
