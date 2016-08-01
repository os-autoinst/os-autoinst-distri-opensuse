# LibreOffice tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11regressiontest";
use strict;
use testapi;

# Case 1503783 - LibreOffice: Verify Main Menu Recent Documents get populated with files accessed and modified using LibreOffice

sub run() {
    my $self = shift;

    # Edit file hello.odt using oowriter
    x11_start_program("oowriter");
    assert_screen 'test-ooffice-1';
    # clicking the writing area to make sure the cursor addressed there
    assert_and_click 'ooffice-writing-area', 'left', 10;
    wait_still_screen;
    type_string "Hello World!";
    assert_screen 'test-ooffice-2';
    send_key "alt-f4";
    assert_screen "ooffice-save-prompt";
    send_key "alt-s";    # Save the file
    assert_screen 'ooffice-save-prompt-2';
    type_string "hello";
    send_key "ret";

    # Check Recent Documents
    wait_still_screen;
    x11_start_program("oowriter");
    assert_screen 'test-ooffice-1';
    send_key "alt-f";
    assert_screen 'oowriter-menus-file';
    send_key "ctrl-u";
    assert_screen 'oowriter-menus-file-recentDucuments';
    send_key_until_needlematch("libreoffice-clear-list", "down");
    send_key "ret";
    wait_still_screen;
    send_key "ctrl-q";    # Quit oowriter

    # Clean test file
    x11_start_program("rm /home/$username/Documents/hello.odt");
}

1;
# vim: set sw=4 et:
