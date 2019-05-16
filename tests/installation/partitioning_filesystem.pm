# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Partition setup via partition proposal menu
# Maintainer: Richard Brown <rbrownccb@opensuse.org>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils qw(is_storage_ng is_sle);
use partition_setup 'select_first_hard_disk';

sub run {
    # open the partinioner
    assert_screen 'edit-proposal-settings';
    wait_screen_change { send_key $cmd{guidedsetup} };
    # Process disk selection if screen is shown. Is relevant for ipmi only as have
    # multiple disks attached there which might contain previous installation
    if (check_var('BACKEND', 'ipmi')) {
        assert_screen([qw(select-hard-disks partition-scheme)]);
        select_first_hard_disk if match_has_tag 'select-hard-disks';
    }

    if (get_var('PARTITIONING_WARNINGS')) {
        assert_screen 'proposal-will-overwrite-manual-changes';
        send_key 'alt-y';
    }
    if (is_storage_ng) {
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

    my $fs = get_var('FILESYSTEM');
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
