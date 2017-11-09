# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Partition setup via partition proposal menu
# Maintainer: Richard Brown <rbrownccb@opensuse.org>

use strict;
use base "y2logsstep";
use testapi;
use utils 'is_storage_ng';

sub run {

    my $fs = get_var('FILESYSTEM');

    # click the button
    assert_and_click 'edit-proposal-settings';

    if (get_var('PARTITIONING_WARNINGS')) {
        if (is_storage_ng) {
            assert_screen 'partition-scheme';
            # No warnings with storage ng stack
            record_soft_failure 'bsc#1055756';
        }
        else {
            assert_screen 'proposal-will-overwrite-manual-changes';
            send_key 'alt-y';
        }
    }
    if (is_storage_ng) {
        # On Xen PV "CDROM" is of the same type as a disk block device so YaST
        # naturally sees it as a "disk". We have to uncheck the "CDROM".
        if (check_var('VIRSH_VMM_TYPE', 'linux')) {
            assert_screen 'select-hard-disk';
            send_key 'alt-e';
            send_key $cmd{next};
        }
        assert_screen 'partition-scheme';
        send_key $cmd{next};
    }
    # select the combo box
    assert_and_click 'default-root-filesystem';

    # select filesystem
    assert_and_click "filesystem-$fs";
    assert_screen "$fs-selected";
    send_key(is_storage_ng() ? $cmd{next} : 'alt-o');

    # make sure we're back from the popup
    assert_screen 'edit-proposal-settings';

    mouse_hide;
}

1;
# vim: set sw=4 et:
