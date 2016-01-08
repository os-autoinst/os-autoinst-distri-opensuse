use strict;
use base "y2logsstep";
use testapi;

sub run() {

    my $fs = get_var('FILESYSTEM');

    # click the button
    assert_and_click 'edit-proposal-settings';

    # select the combo box
    assert_and_click 'default-root-filesystem';

    # select filesystem
    assert_and_click "filesystem-$fs";
    assert_screen "$fs-selected";
    assert_and_click 'ok-button';

    # make sure we're back from the popup
    assert_screen 'edit-proposal-settings';

    mouse_hide;
}

1;
# vim: set sw=4 et:
