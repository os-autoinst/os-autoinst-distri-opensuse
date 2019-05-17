# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
#
# Summary: Ensure the root logical volume can be resized on bigger harddisks.
# Maintainer: Oliver Kurz <okurz@suse.de>
# Tags: bsc#989976 bsc#1000165

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils 'is_storage_ng';
use partition_setup 'resize_partition';

sub run {
    die "Test needs at least 40 GB HDD size" unless (get_required_var('HDDSIZEGB') > 40);
    send_key $cmd{expertpartitioner};
    if (is_storage_ng) {
        # start with preconfigured partitions
        send_key 'down';
        send_key 'ret';
    }
    assert_screen 'expert-partitioner';
    send_key_until_needlematch 'volume-management', 'down';
    send_key 'tab';
    send_key_until_needlematch 'volume-management-root-selected', 'down';
    resize_partition;
    send_key $cmd{accept};
    assert_screen 'partitioning-subvolumes-shown';
}

1;
