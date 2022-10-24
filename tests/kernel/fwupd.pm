# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: fwupd
# Summary: fwupd smoke test
# Maintainer: Kernel QE <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Backends 'is_pvm';

sub run {
    select_serial_terminal;

    # Install and start fwupd
    zypper_call "in fwupd";
    systemctl "start fwupd";

    # Get all devices that support firmware updates
    assert_script_run "fwupdmgr get-devices" unless is_pvm;
    # Gets the configured remotes
    assert_script_run "fwupdmgr get-remotes";
}

1;
