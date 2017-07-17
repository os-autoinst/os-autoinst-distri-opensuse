# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Firefox Case#1479190: Add-ons - Appearance
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run {
    my ($self) = @_;
    $self->start_firefox;

    send_key "ctrl-w";
    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_and_click('firefox-appearance-tabicon');
    assert_screen('firefox-appearance-default', 30);

    sleep 1;
    send_key "alt-d";
    sleep 1;
    type_string "addons.mozilla.org/en-US/firefox/addon/opensuse\n";
    assert_screen('firefox-appearance-mozilla_addons', 90);
    send_key "alt-f10";
    wait_still_screen 3;
    assert_and_click "firefox-appearance-addto";
    assert_screen('firefox-appearance-installed', 90);
    # Undo the theme installation
    send_key "alt-u";

    # Exit
    for my $i (1 .. 2) { sleep 1; send_key "ctrl-w"; }

    $self->exit_firefox;
}
1;
# vim: set sw=4 et:
