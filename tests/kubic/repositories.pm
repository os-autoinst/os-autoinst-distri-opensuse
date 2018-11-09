# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure Kubic repositories
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils "zypper_call";

sub run {
    # MIRROR_HTTP it's a mirror of the REPO including unreleased packages
    # and it also contains everything from the current ISO under test
    if (get_var('MIRROR_HTTP')) {
        # Kubic repos might have *older* version of packages compared MIRROR_HTTP
        # Any pkg installation from now on, should come from the MIRROR_HTTP
        zypper_call("mr -da");
        my $mirror = get_required_var('MIRROR_HTTP');
        zypper_call("--no-gpg-check ar -f '$mirror' mirror_http");
    }
    zypper_call('ref');
}

sub test_flags {
    return {fatal => 1};
}

1;

