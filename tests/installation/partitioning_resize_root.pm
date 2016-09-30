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
# Maintainer: okurz@suse.de
# Tags: bsc#989976, bsc#1000165

# G-Summary: Add test to resize the root volume of a LVM
#    Verification test for bsc#989976, bsc#1000165.
#
#    The installer by default selects a root volume of maximum 40GB regardless of
#    the available space. If the user resizes the volume, the btrfs subvolumes are
#    not shown (although they are still created). This test verifies the subvolumes
#    are present after resizing the root volume. The home volume is disabled
#    (TOGGLEHOME=1) to actually provide the space for the root volume. Otherwise the
#    available space would all be consumed by the home volume.
#
#    Triggered with variables:
#    * TOGGLEHOME=1
#    * RESIZE_ROOT_VOLUME=1
#    * HDDSIZEGB=50
#
#    Local verification run: http://lord.arch/tests/4961
# G-Maintainer: Oliver Kurz <okurz@suse.de>

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
