# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: RT installation media should contain devel packages
# Maintainer: mkravec <mkravec@suse.com>

use base "opensusebasetest";
use testapi;
use utils;

# https://fate.suse.com/316652
sub run {
    select_console 'root-console';
    my $pkgs = "babeltrace-devel lttng-tools-devel kernel-rt-devel kernel-rt_debug-devel kernel-devel-rt libcpuset-devel lttng-tools";
    zypper_call "in $pkgs";
}

1;
