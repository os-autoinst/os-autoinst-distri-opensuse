# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use testapi;
use utils;
use lockapi;

sub run() {
    my $self = shift;
    #wait for adminserver
    mutex_lock("images_registered");
    mutex_unlock("images_registered");


    assert_script_run "possyncimages";

    mutex_create("bs1_images_synced");
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
