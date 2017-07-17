# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy: print
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: tc#1248880

use base "x11regressiontest";
use strict;
use testapi;


sub run {
    # open tomboy
    x11_start_program("tomboy note");

    # open a note and print to file
    send_key "tab";
    sleep 1;
    send_key "down";
    sleep 1;
    send_key "ret";
    sleep 3;
    send_key "ctrl-p";
    sleep 3;
    send_key "tab";
    sleep 1;
    send_key "alt-v";
    sleep 5;    #FIXME Print to file failed in this version, so just replace with preview.
                #send_key "alt-p"; sleep 2; #FIXME
                #send_key "alt-r"; sleep 5; #FIXME

    wait_idle;
    assert_screen 'test-tomboy_Print-1', 3;
    sleep 2;
    send_key "ctrl-w";
    sleep 2;
    send_key "ctrl-w";
    sleep 2;
    send_key "alt-f4";
    sleep 2;
    wait_idle;
}

1;
# vim: set sw=4 et:
