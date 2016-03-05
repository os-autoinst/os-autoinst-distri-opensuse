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

# Case 1503962 - Shotwell: Import image files

sub run() {
    my $self     = shift;
    my @pictures = qw/shotwell_test.jpg shotwell_test.png/;

    x11_start_program("shotwell");
    assert_screen 'shotwell-first-launch';
    wait_screen_change { send_key "ret"; };

    # Import two test pictures into the library
    $self->import_pictures(\@pictures);

    # Display the first picture
    send_key "alt-home";
    send_key "ret";
    assert_screen 'shotwell-display-picture';
    send_key "esc";
    send_key "ctrl-q";    # Quit shotwell

    # Clean shotwell's library then remove the test pictures
    $self->clean_shotwell();
}

1;
# vim: set sw=4 et:
