# LibreOffice tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: LibreOffice: Verify Main Menu Recent Documents get populated
#   with files accessed and modified using LibreOffice (Case 1503783)
# Maintainer: Chingkai <qkzhu@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle is_tumbleweed);

sub run {
    # Edit file hello.odt using oowriter
    x11_start_program('oowriter');
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
    x11_start_program('oowriter');
    # Because of bsc#1074057 alt-f is not working in libreoffice under wayland
    # use another way to replace alt-f in SLED15
    if (is_sle '15+') {
        assert_and_click 'ooffice-writing-file', 'left', 10;
    }
    else {
        send_key "alt-f";    # is_sle('<15') and openSUSE all need to send key
    }
    assert_screen 'oowriter-menus-file';
    if (is_tumbleweed || is_sle('15+')) {
        send_key 'down';
        wait_still_screen 3;
        send_key 'u';
    }
    else {
        send_key "ctrl-u";
    }
    assert_screen 'oowriter-menus-file-recentDocuments';
    send_key_until_needlematch("libreoffice-clear-list", "down");
    send_key "ret";
    assert_screen 'test-ooffice-1';

    # Quit oowriter
    assert_and_click 'ooffice-writing-area', 'left', 10;
    send_key "ctrl-q";

    assert_screen 'generic-desktop';

    # Clean test file
    x11_start_program("rm /home/$username/Documents/hello.odt", valid => 0);
}

1;
