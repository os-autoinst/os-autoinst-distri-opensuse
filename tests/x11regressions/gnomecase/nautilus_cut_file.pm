# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: testcase 4158-1249067 move a file with nautilus
# Maintainer: Xudong Zhang <xdzhang@suse.com>

use base "x11regressiontest";
use strict;
use testapi;

sub run {
    x11_start_program("nautilus");
    assert_screen 'nautilus-launched';
    x11_start_program("touch newfile");

    send_key_until_needlematch 'nautilus-newfile-matched', 'right', 15;
    sleep 2;
    send_key "ctrl-x";
    send_key_until_needlematch 'nautilus-Downloads-matched', 'left', 5;
    send_key "ret";
    sleep 2;
    send_key "ctrl-v";    #paste to dir ~/Downloads
    assert_screen "nautilus-newfile-moved";
    sleep 2;
    send_key "alt-up";                      #back to home dir from ~/Downloads
    assert_screen 'nautilus-no-newfile';    #assure newfile moved
    send_key "ctrl-w";                      #close nautilus

    #remove the newfile, rm via cmd to avoid file moving to trash
    x11_start_program("rm Downloads/newfile");
}

1;
# vim: set sw=4 et:
