# Shotwell tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use base "x11regressiontest";
use strict;
use testapi;

# Case 1503811 - Shotwell: Delete or edit an imported image

sub run() {
    my $self     = shift;
    my @pictures = qw/shotwell_test.jpg shotwell_test.png/;

    x11_start_program("shotwell");
    assert_screen 'shotwell-launched';

    # Import two test pictures into the library
    $self->import_pictures(\@pictures);

    # Edit & Delete the first picture
    send_key "alt-home";
    send_key "ret";
    assert_screen 'shotwell-display-picture';
    send_key "ctrl-r";    # Rotate the picture
    assert_screen 'shotwell-rotate-picture';
    send_key "ctrl-o";    # Crop the picture
    assert_screen 'shotwell-crop-toolbar';
    send_key "ret";
    assert_screen 'shotwell-crop-picture';
    send_key "shift-delete";    # Remove picture from library
    assert_screen 'shotwell-remove-prompt';
    send_key "alt-r";
    sleep 2;
    send_key "esc";
    wait_still_screen;
    assert_screen 'shotwell-removed-picture';
    send_key "ctrl-q";          # Quit shotwell

    # Clean shotwell's library then remove the test pictures
    $self->clean_shotwell();
}

1;
# vim: set sw=4 et:
