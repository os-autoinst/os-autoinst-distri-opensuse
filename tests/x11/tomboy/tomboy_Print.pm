# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: test tomboy: print
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: tc#1248880

use base "x11test";
use strict;
use warnings;
use testapi;


sub run {
    # open tomboy
    x11_start_program('tomboy note', valid => 0);

    # open a note and print to file
    send_key "tab";
    send_key "down";
    send_key "ret";
    send_key "ctrl-p";
    send_key "tab";
    send_key "alt-v";
    assert_screen 'test-tomboy_Print-1';
    send_key "ctrl-w";
    send_key "ctrl-w";
    send_key "alt-f4";
}

1;
