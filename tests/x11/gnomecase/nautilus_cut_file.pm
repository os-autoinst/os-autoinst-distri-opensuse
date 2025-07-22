# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nautilus
# Summary: testcase 4158-1249067 move a file with nautilus
# - Launch nautilus
# - Create a test file called "newfile"
# - Select the file in nautilus and send "CTRL-X"
# - Open Downloads folder
# - Send "CTRL-V" and check
# - Return to homedir and check for "newfile"
# - Cleanup
# Maintainer: Xudong Zhang <xdzhang@suse.com>

use base "x11test";
use testapi;

sub run {
    x11_start_program('nautilus');
    x11_start_program("touch newfile", valid => 0);

    assert_and_click "nautilus-newfile-matched";
    send_key "ctrl-x";
    assert_and_dclick "nautilus-Downloads-matched";
    # paste to ~/Downloads
    send_key "ctrl-v";
    # assure file moved, no matter file is highlighted or not
    assert_screen([qw(nautilus-newfile-moved nautilus-newfile-moved-no-focus)]);
    if (match_has_tag('nautilus-newfile-moved-no-focus')) {
        record_soft_failure 'poo#45527 [tw][desktop] pasted files not always highlighted in openqa';
        save_screenshot;
    }
    # back to home dir
    send_key "alt-up";
    assert_screen 'nautilus-no-newfile';
    # close nautilus
    send_key "ctrl-w";

    #remove the newfile, rm via cmd to avoid file moving to trash
    x11_start_program("rm Downloads/newfile", valid => 0);
}

1;
