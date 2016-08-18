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

sub run() {
    assert_screen "inst-timezone", 125 || die 'no timezone';
    if (get_var('LIVECD')) {
        # on live cd we might get weird combinations assigned, even if the ISO
        # does not change, it behaves different
        send_key "alt-$_" foreach (('x', 't'));
    }
    else {
        send_key $cmd{next};
    }
}

1;
# vim: set sw=4 et:
