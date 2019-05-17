# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary: Some simple actions to test the new expert partitioner.
# Maintainer: Christopher Hofmann <cwh@suse.de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;

sub run() {
    send_key $cmd{expertpartitioner};
    assert_screen 'expert-partitioner';

    # Delete home partition
    assert_and_click 'hard-disks';
    assert_and_click 'home';

    wait_screen_change { send_key 'alt-d' };    # Delete
    wait_screen_change { send_key 'alt-y' };    # Confirm with 'yes'
    assert_and_click 'hard-disks';
    save_screenshot;

    # Add a btrfs subvolume
    assert_and_click 'btrfs';
    wait_screen_change { send_key 'alt-e' };    # Edit
    wait_screen_change { send_key 'alt-a' };    # Add
    type_string '@/usr/lib';
    wait_screen_change { send_key 'alt-n' };    # noCoW
    wait_screen_change { send_key 'alt-o' };    # Ok
    wait_screen_change { send_key 'alt-o' };    # Ok

    wait_screen_change { send_key $cmd{accept} };
    assert_and_click 'see-details';
    die "/home still there" if check_screen('home', 0);
}

1;
