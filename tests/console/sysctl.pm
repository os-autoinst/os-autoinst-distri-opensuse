# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: procps
# Summary: test sysctl because it can go wrong https://bugzilla.opensuse.org/show_bug.cgi?id=1077746
# - Run 'sysctl -w vm.swappiness=59'
# - Check /proc/sys/vm/swappiness and validate value "59"
# Maintainer: Bernhard M. Wiedemann <bwiedemann+openqa@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    assert_script_run 'sysctl -w vm.swappiness=59';
    validate_script_output 'cat /proc/sys/vm/swappiness', sub { m/^59$/ };
}

1;
