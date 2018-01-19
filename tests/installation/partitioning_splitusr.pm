# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test custom partitioning selection: Split off '/usr' partition
# Maintainer: Oliver Kurz <okurz@suse.de>

use base "y2logsstep";
use strict;
use testapi;
use version_utils 'is_storage_ng';
use partition_setup 'addpart';

sub run {
    send_key $cmd{expertpartitioner};    # open Expert partitioner
    if (is_storage_ng) {
        # start with preconfigured partitions
        send_key 'down';
        send_key 'ret';
    }

    # select root partition
    send_key "right";
    send_key "down";                     # only works with multiple HDDs
    send_key "right";
    send_key "down";
    send_key "tab";
    send_key "tab";
    send_key "down";

    wait_screen_change { send_key $cmd{resize} };    # Resize
    send_key(is_storage_ng() ? 'alt-c' : 'alt-u');   # Custom size
    send_key $cmd{size_hotkey} if is_storage_ng;
    type_string '1.5G';
    send_key(is_storage_ng() ? $cmd{next} : 'ret');
    if (is_storage_ng) {
        wait_screen_change { send_key 'alt-s' };
        send_key_until_needlematch 'vda-selected', 'left';    # Select vda again, not vda1
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
# vim: set sw=4 et:
