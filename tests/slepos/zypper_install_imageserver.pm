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
    assert_script_run "zypper -n --no-gpg-checks in --auto-agree-with-licenses -t pattern SLEPOS_Image_Server > /dev/$serialdev";
}

sub test_flags {
    return {fatal => 1};
}

1;
