# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test network connectivity
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    # check the network configuration
    script_run "ip addr show";
    script_run "cat /etc/resolv.conf";

    # ping
    assert_script_run 'ping -c 1 127.0.0.1';
    assert_script_run 'ping -c 1 ::1';

    # curl
    my $openqa = is_opensuse ? "openqa.opensuse.org" : "openqa.suse.de";
    script_retry("curl -Lf --head $openqa", retry => 5, delay => 60);    # openQA Networking (required for mirrors)
    script_retry("curl -Lf --head github.com", retry => 5, delay => 60);    # Required for kubeadm (behind the scenes)

}

sub test_flags {
    return {fatal => 1};
}

1;

