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
use version_utils qw(is_leap is_storage_ng is_sle sle_version_at_least);
use partition_setup '%partition_roles';

sub run {
    assert_screen 'partitioning-edit-proposal-button', 40;

    if (get_var("DUALBOOT")) {
        if (is_sle && sle_version_at_least('15')) {
            record_soft_failure('bsc#1089723 Make sure keep the existing windows partition');
            assert_screen "delete-partition";
            send_key "alt-g";
            assert_and_click "resize-or-remove-ifneeded";
            send_key "up";
            assert_and_click "resize-ifneeded";
            for (1 .. 3) { send_key "alt-n"; }
        }
    }

    # Storage NG introduces a new partitioning dialog. We detect this
    # by the existence of the "Guided Setup" button and set the
    # STORAGE_NG variable so later tests know about this.
    if (match_has_tag('storage-ng')) {
        set_var('STORAGE_NG', 1);
        # Define changed shortcuts
        $cmd{addraid}          = 'alt-r';
        $cmd{customsize}       = 'alt-o';
        $cmd{donotformat}      = 'alt-t';
        $cmd{exp_part_finish}  = 'alt-n';
        $cmd{filesystem}       = 'alt-r';
        $cmd{guidedsetup}      = 'alt-g';
        $cmd{rescandevices}    = 'alt-r';
        $cmd{resize}           = 'alt-r';
        $cmd{raw_volume}       = 'alt-r';
        $cmd{enable_snapshots} = 'alt-a';
        # Set shortcut for role selection when creating partition
        $partition_roles{raw} = $cmd{raw_volume};

        if (check_var('DISTRI', 'opensuse')) {
            #TODO remove SYSTEM_ROLE_FIRST_FLOW usages with versions checks
            $cmd{expertpartitioner} = get_var('SYSTEM_ROLE_FIRST_FLOW') ? 'alt-e' : 'alt-x';
            $cmd{enablelvm}         = get_var('SYSTEM_ROLE_FIRST_FLOW') ? 'alt-e' : 'alt-a';
            $cmd{encryptdisk}       = get_var('SYSTEM_ROLE_FIRST_FLOW') ? 'alt-a' : 'alt-l';
        }
    }

    if (get_var("DUALBOOT")) {
        assert_screen 'partitioning-windows', 40;
    }
}

1;
