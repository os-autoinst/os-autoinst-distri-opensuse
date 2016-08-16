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
use warnings;
use base "y2logsstep";
use testapi;

# Entry test code
sub run() {

    assert_screen 'partitioning-edit-proposal-button', 40;

    if (get_var("DUALBOOT")) {
        assert_screen 'partitioning-windows', 40;
    }

}

1;
# vim: set sw=4 et:
