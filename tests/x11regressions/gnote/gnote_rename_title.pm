# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Rename gnote title
# Maintainer: Xudong Zhang <xdzhang@suse.com>
# Tags: tc#1436169

use base "x11regressiontest";
use strict;
use testapi;


sub run {
    x11_start_program("gnote");
    assert_screen "gnote-first-launched", 10;
    send_key "ctrl-n";
    assert_screen 'gnote-new-note', 5;
    send_key "up";
    send_key "up";
    type_string "new title-opensuse\n";
    send_key "ctrl-tab";    #jump to toolbar
    sleep 2;
    send_key "ret";         #back to all notes interface
    sleep 5;                #it needs seconds to refresh title
    send_key_until_needlematch 'gnote-new-note-title-matched', 'down', 6;
    send_key "delete";
    sleep 2;
    send_key "tab";
    sleep 2;
    send_key "ret";
    sleep 2;
    send_key "ctrl-w";
}

1;
# vim: set sw=4 et:
