# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: MozillaThunderbird
# Summary: Thunderbird installation
# - Go to text console
# - Stop packagekit
# - Install MozillaThunderbird
# - Go to graphic console
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    quit_packagekit;
    zypper_call("in MozillaThunderbird", exitcode => [0, 102, 103]);

    select_console 'x11';
}

sub test_flags {
    return {milestone => 1};
}

1;

