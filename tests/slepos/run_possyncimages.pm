# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Basic SLEPOS test
# Maintainer: Vladimir Nadvornik <nadvornik@suse.cz>

use base "basetest";
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
