# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;

sub run() {
    my $self = shift;

    #todo: add another images if needed
    my $images_ref = get_var_array('IMAGE_OFFLINE_CREATOR');
    foreach my $image (@{$images_ref}) {
        #todo: build offline images using image creator

        #    upload_asset '/var/lib/SLEPOS/system/images/slepos-image-offline-graphical.raw';
    }
}
sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
