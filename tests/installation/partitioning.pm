# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check initial partitioning screen and prepare optional substeps
# Maintainer: Joachim Rauch <jrauch@suse.com>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run {
    assert_screen 'partitioning-edit-proposal-button', 40;

    # Storage NG introduces a new partitioning dialog. We detect this
    # by the existence of the "Guided Setup" button and set the
    # STORAGE_NG variable so later tests know about this.
    if (match_has_tag('storage-ng')) {
        set_var('STORAGE_NG', 1);
        # Define changed shortcuts
        $cmd{donotformat} = 'alt-t';
        $cmd{addraid}     = 'alt-i';
        if (check_var('DISTRI', 'opensuse')) {
            $cmd{expertpartitioner} = 'alt-x';
            $cmd{rescandevices}     = 'alt-c';

        }
        else {
            $cmd{filesystem} = 'alt-a';
        }
    }

    if (get_var("DUALBOOT")) {
        assert_screen 'partitioning-windows', 40;
    }
}

1;
# vim: set sw=4 et:
