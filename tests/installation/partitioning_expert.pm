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

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    wait_screen_change { send_key 'alt-x-c' };    # Expert partitioner, using current proposal
    assert_screen 'expert-partitioner';

    # Delete home partition
    assert_and_click 'hard-disks';
    assert_and_click 'home';

    wait_screen_change { send_key 'alt-d' };      # Delete
    assert_screen 'really-delete';
    wait_screen_change { send_key 'alt-y' };      # Confirm with 'yes'

    # Add a btrfs subvolume
    assert_and_click 'btrfs';
    wait_screen_change { send_key 'alt-d' };      # Edit
    wait_screen_change { send_key 'alt-a' };      # Add
    type_string '@/usr/lib';
    wait_screen_change { send_key 'alt-n' };      # noCoW
    save_screenshot;
    wait_screen_change { send_key 'alt-o' };      # Ok
    wait_screen_change { send_key 'alt-o' };      # Ok

    wait_screen_change { send_key $cmd{accept} };
    assert_and_click 'see-details';
    assert_screen 'usr-lib';
    die "/home still there" if check_screen('home', 0);
}

1;
# vim: set sw=4 et:
