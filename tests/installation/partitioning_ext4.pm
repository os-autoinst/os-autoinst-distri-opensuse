#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use testapi;

sub run() {

    # click the button
    assert_and_click 'edit-proposal-settings';

    # select the combo box
    assert_and_click 'default-root-filesystem';

    # select ext4
    assert_and_click 'filesystem-ext4';
    assert_screen 'ext4-selected';
    assert_and_click 'ok-button';

    # make sure we're back from the popup
    assert_screen 'edit-proposal-settings';

    mouse_hide;
}

1;
# vim: set sw=4 et:
