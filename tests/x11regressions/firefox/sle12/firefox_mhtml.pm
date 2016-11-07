# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Case#1436084: Firefox: Open IE MHTML Files
# Maintainer: wnereiz <wnereiz@gmail.com>

use strict;
use base "x11regressiontest";
use testapi;

sub run() {
    my ($self) = @_;
    $self->start_firefox;


    # Fetch mht file to shm
    x11_start_program("wget " . autoinst_url . "/data/x11regressions/ie10.mht -O /dev/shm/ie10.mht");

    send_key "ctrl-w";
    wait_still_screen 3;
    send_key "ctrl-shift-a";
    assert_screen('firefox-addons_manager', 90);

    assert_and_click "firefox-searchall-addon";
    type_string "unmht\n";
    assert_and_click('firefox-mhtml-unmht');
    for my $i (1 .. 2) { send_key "tab"; }
    send_key "spc";
    assert_screen('firefox-mhtml-unmht_installed', 90);

    send_key "ctrl-w", 1;

    send_key "alt-d";
    type_string "file:///dev/shm/ie10.mht\n";
    assert_screen('firefox-mhtml-loadpage', 60);

    # Exit and Clear
    $self->exit_firefox;
    wait_still_screen 3;
    x11_start_program("rm /dev/shm/ie10.mht");
}
1;
# vim: set sw=4 et:
