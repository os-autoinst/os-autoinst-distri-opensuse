# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: Full patch system using zypper
# - Calls zypper in quiet mode and patch system
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console 'root-console';
    quit_packagekit;
    fully_patch_system;
    assert_script_run("rpm -q libzypp zypper");

    # XXX: does this below make any sense? what if updates got
    # published meanwhile?
    clear_console;    # clear screen to see that second update does not do any more
    zypper_call("-q patch");
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
