# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: testcase 4158-1249067 move a file with nautilus
# Maintainer: Xudong Zhang <xdzhang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;

sub run {
    x11_start_program('nautilus');
    x11_start_program("touch newfile", valid => 0);

    send_key_until_needlematch 'nautilus-newfile-matched', 'right', 15;
    send_key "ctrl-x";
    send_key_until_needlematch 'nautilus-Downloads-matched', 'left', 5;
    send_key "ret";
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
