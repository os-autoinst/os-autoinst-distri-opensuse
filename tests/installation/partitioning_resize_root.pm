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

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    die "Test needs at least 40 GB HDD size" unless (get_required_var('HDDSIZEGB') > 40);
    send_key $cmd{expertpartitioner};
    assert_screen 'expert-partitioner';
    send_key_until_needlematch 'volume-management', 'down';
    send_key 'tab';
    send_key_until_needlematch 'volume-management-root-selected', 'down';
    send_key $cmd{resize};
    assert_screen 'volume-management-resize-maximum-selected';
    send_key $cmd{ok};
    send_key $cmd{accept};
    assert_screen 'partitioning-subvolumes-shown';
}

1;
# vim: set sw=4 et:
