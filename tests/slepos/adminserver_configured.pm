# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Adminserver configured mutex
# Maintainer: Pavel Sladek <psladek@suse.cz>

use base "basetest";
use testapi;
use utils;
use lockapi;

sub run {
    my $self = shift;

    mutex_create("adminserver_configured");

}

sub test_flags {
    return {fatal => 1};
}

1;
