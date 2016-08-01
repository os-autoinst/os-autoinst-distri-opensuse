# Shotwell tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use base "x11regressiontest";
use strict;
use testapi;

# Case 1503754 - Shotwell: Shotwell: Export Images to Folder

sub run() {
    my $self     = shift;
    my @pictures = qw/shotwell_test.jpg shotwell_test.png/;

    x11_start_program("shotwell");
    assert_screen 'shotwell-launched';

    # Import two test pictures into the library
    $self->import_pictures(\@pictures);

    # Export the first picture(png format) to jpeg format
    send_key "alt-home";
    send_key "ctrl-shift-e";
    assert_screen 'shotwell-export-prompt';
    send_key "alt-f";    # Choose jepg format to export
    send_key "down";
    assert_screen 'shotwell-export-jepg';
    send_key "alt-o";
    assert_and_dclick "shotwell-export-to-desktop";
    send_key "ret";
    wait_still_screen;
    send_key "ctrl-q";    # Quit shotwell
    wait_still_screen;

    # Check the exported file
    x11_start_program("nautilus");
    send_key "ctrl-l", 1;
    type_string "/home/$username/Desktop\n";
    send_key "ret";
    assert_screen 'shotwell-exported-file';
    send_key "ctrl-w";

    # Clean shotwell's library then remove the test pictures
    $self->clean_shotwell();
    x11_start_program("rm /home/$username/Desktop/shotwell_test.jpg");
}

1;
# vim: set sw=4 et:
