# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use base "y2logsstep";
use testapi;
use utils;

sub run() {
    # Eject the DVD
    send_key "ctrl-alt-f3";
    assert_screen('text-login');
    send_key "ctrl-alt-delete";

    # Bug in 13.1?
    power('reset');

    # eject_cd;

    unlock_if_encrypted;
}

1;

# vim: set sw=4 et:
