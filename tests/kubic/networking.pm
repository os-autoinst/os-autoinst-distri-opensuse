# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test network connectivity
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run {
    # ping
    assert_script_run 'ping -c 1 127.0.0.1';
    assert_script_run 'ping -c 1 ::1';

    # curl
    assert_script_run 'curl -L openqa.opensuse.org';    # openQA Networking (required for mirrors)
    assert_script_run 'curl -L github.com';             # Required for kubeadm (behind the scenes)

}

sub test_flags {
    return {fatal => 1};
}

1;

