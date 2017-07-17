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
use lockapi;

sub run {
    #wait for adminserver
    mutex_lock("images_registered");
    mutex_unlock("images_registered");


    assert_script_run "possyncimages", 300;

    mutex_create("bs1_images_synced");
}

sub test_flags {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
