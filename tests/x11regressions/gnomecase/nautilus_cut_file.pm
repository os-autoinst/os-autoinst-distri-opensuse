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

use base "x11regressiontest";
use strict;
use testapi;

sub run {
    x11_start_program('nautilus');
    x11_start_program("touch newfile", valid => 0);

    send_key_until_needlematch 'nautilus-newfile-matched', 'right', 15;
    send_key "ctrl-x";
    send_key_until_needlematch 'nautilus-Downloads-matched', 'left', 5;
    send_key "ret";
    send_key "ctrl-v";    #paste to dir ~/Downloads
    assert_screen "nautilus-newfile-moved";
    send_key "alt-up";                      #back to home dir from ~/Downloads
    assert_screen 'nautilus-no-newfile';    #assure newfile moved
    send_key "ctrl-w";                      #close nautilus

    #remove the newfile, rm via cmd to avoid file moving to trash
    x11_start_program("rm Downloads/newfile", valid => 0);
}

1;
# vim: set sw=4 et:
