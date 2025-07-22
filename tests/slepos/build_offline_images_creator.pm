# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
use testapi;
use utils;

sub run {
    my $self = shift;

    #todo: add another images if needed
    my $images_ref = get_var_array('IMAGE_OFFLINE_CREATOR');
    foreach my $image (@{$images_ref}) {
        #todo: build offline images using image creator

        #    upload_asset '/var/lib/SLEPOS/system/images/slepos-image-offline-graphical.raw';
    }
}
sub test_flags {
    return {fatal => 1};
}

1;
