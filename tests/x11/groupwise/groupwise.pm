# Groupwise tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: novell-groupwise-gwclient
# Summary: Groupwise client check
# - Stop packagekit service
# - Add groupwise repository
# - Import keys
# - Install novell-groupwise-gwclient
# - Remove groupwise repository
# - Save screenshot
# - Lauch groupwise
# - Exit groupwise
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use strict;
use warnings;
use base "x11test";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run() {
    my ($self) = @_;
    select_serial_terminal;
    quit_packagekit;

    # add repository and install groupwise
    zypper_call("ar http://download.suse.de/ibs/SUSE:/Factory:/Head:/Internal/standard/ groupwise_repo");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("in novell-groupwise-gwclient", exitcode => [0, 102, 103]);
    zypper_call("rr groupwise_repo");
    save_screenshot;

    select_console 'x11';
    x11_start_program('groupwise');
    send_key "alt-f4";
}

1;
