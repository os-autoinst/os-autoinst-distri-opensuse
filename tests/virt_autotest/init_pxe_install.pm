# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
use strict;
use warnings;
use File::Basename;
use base "opensusebasetest";
use testapi;

sub run() {
    # Wait initial screen for ipmi bootloader
    assert_screen "virttest-bootloader", 60;

    # Wait the second screen for ipmi bootloader
    send_key_until_needlematch "virttest-boot-into-pxe", "f12", 3, 60;

    # Wait pxe management screen
    send_key_until_needlematch "virttest-pxe-menu", "f12", 200, 1;

    # Login to command line of pxe management
    send_key_until_needlematch "virttest-pxe-edit-prompt", "esc", 60, 1;

    # Execute installation command on pxe management cmd console
    my $type_speed = 20;
    my $image_path = get_var("HOST_IMG_URL");

    type_string ${image_path} . " ", $type_speed;
    type_string "vga=791 ",   $type_speed;
    type_string "Y2DEBUG=1 ", $type_speed;
    if (check_var("INSTALL_TO_OTHERS", 1)) {
        type_string "video=1024x768-16 ", $type_speed;
    }
    else {
        type_string "xvideo=1024x768 ", $type_speed;
    }
    type_string "console=ttyS1,115200 ", $type_speed;    # to get crash dumps as text
    type_string "console=tty ",          $type_speed;
    send_key 'ret';
    save_screenshot;
}

sub test_flags {
    return {important => 1};
}

1;

