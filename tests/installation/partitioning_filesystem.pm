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
use version_utils 'is_storage_ng';
use partition_setup 'unselect_xen_pv_cdrom';

sub run {

    my $fs = get_var('FILESYSTEM');

    # open the partinioner
    assert_screen 'edit-proposal-settings';
    wait_screen_change { send_key $cmd{guidedsetup} };

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
        unselect_xen_pv_cdrom;
        assert_screen [qw(partition-scheme existing-partitions)];
        if (match_has_tag 'existing-partitions') {
            send_key $cmd{next};
            assert_screen 'partition-scheme';
        }
        send_key $cmd{next};
    }
    # select the combo box
    assert_screen 'default-root-filesystem';
    send_key 'alt-f';
    assert_screen 'filesystem-root-menu-selected';

    # select filesystem
    send_key 'home';
    send_key_until_needlematch("filesystem-$fs", 'down', 20, 3);
    send_key 'ret' if check_var('VIDEOMODE', 'text');

    assert_screen "$fs-selected";
    send_key(is_storage_ng() ? $cmd{next} : 'alt-o');

    # make sure we're back from the popup
    assert_screen 'edit-proposal-settings';

    mouse_hide unless check_var('VIDEOMODE', 'text');
}

1;
# vim: set sw=4 et:
