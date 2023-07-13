# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test custom partitioning selection: Split off '/usr' partition
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils qw(is_storage_ng is_tumbleweed);
use partition_setup 'addpart';

sub run {
    send_key $cmd{expertpartitioner};    # open Expert partitioner
    if (is_storage_ng) {
        # start with preconfigured partitions
        send_key 'down';
        send_key 'ret';
    }

    # select root partition
    send_key_until_needlematch 'vda-selected', 'right';
    wait_screen_change { send_key 'alt-p' } if is_storage_ng;
    send_key "tab";
    wait_screen_change { send_key "tab" };
    send_key "home";
    wait_still_screen(2);
    send_key_until_needlematch 'root-partition-selected', 'down', 6, 2;    # Select root partition

    # Resize has been moved under drop down button Modify in storage-ng
    if (is_storage_ng) {
        wait_screen_change { send_key 'alt-m' };
        wait_still_screen(2);
        send_key 'down' for (0 .. 1);
        save_screenshot;
        send_key 'ret';
    }
    wait_screen_change { send_key $cmd{resize} };    # Resize
    send_key 'alt-u';    # Custom size
    send_key $cmd{size_hotkey} if is_storage_ng;
    type_string '5G';
    send_key(is_storage_ng() ? $cmd{next} : 'ret');
    if (is_storage_ng) {
        # warning: / should be >= 10 GiB or disable snapshots
        assert_screen 'partition-splitusr-root-warning';
        wait_screen_change { send_key 'alt-y' };    # accept warning for small /
        wait_screen_change { send_key 'alt-s' };
        send_key_until_needlematch 'vda-selected', 'left';    # Select vda again
    }

    # add /usr
    # Sending space and backspace to break bad completion e.g. /usr/local
    addpart(role => 'data', size => '5000', mount => "/usr \b");

    assert_screen "partition-splitusr-finished";
    wait_still_screen 1;
    wait_screen_change { send_key $cmd{accept} };
    send_key "alt-y";    # Quit the warning window
}

1;
