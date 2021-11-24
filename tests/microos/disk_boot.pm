# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot from disk and login into MicroOS
# Maintainer: Panagiotis Georgiadis <pgeorgiadis@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;

use microos "microos_login";

sub run {
    shift->wait_boot(bootloader_time => 300);
    microos_login;
}

sub test_flags {
    return {fatal => 1};
}

1;
