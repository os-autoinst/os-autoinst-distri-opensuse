# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: gnote
# Summary: gnote startup
# - Install gnote if necessary
# - Launch gnote
# - Close application
# Maintainer: Xudong Zhang <xdzhang@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_tumbleweed is_sle);

sub run {
    if (is_tumbleweed || is_sle('>=15-sp4')) {
        select_console('root-console');
        quit_packagekit;
        zypper_call('in gnote');
        select_console('x11');
    }
    x11_start_program('gnote');
    send_key "ctrl-w";
}

# add milestone flag to save gnote installation in lastgood vm snapshot
sub test_flags {
    return {milestone => 1};
}

1;
