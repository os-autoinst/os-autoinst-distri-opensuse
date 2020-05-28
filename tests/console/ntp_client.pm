# Copyright (C) 2018-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check for NTP clients
# Maintainer: Dominik Heidler <dheidler@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    assert_script_run 'timedatectl';

    if (is_sle) {
        systemctl 'enable chronyd';
        systemctl 'start chronyd';
    }

    # ensure that ntpd is neither installed nor enabled nor active
    systemctl 'is-active ntpd',  expect_false => 1;
    systemctl 'is-enabled ntpd', expect_false => 1;
    if (script_run('rpm -q ntp') == 0) {
        # ntp should not be installed by default as we are using chrony
        record_soft_failure 'boo#1114189 - ntp is installed by default';
    }

    # ensure that systemd-timesyncd is neither enabled nor active
    systemctl 'is-active systemd-timesyncd',  expect_false => 1;
    systemctl 'is-enabled systemd-timesyncd', expect_false => 1;

    # ensure that chronyd is running
    systemctl 'is-enabled chronyd';
    systemctl 'is-active chronyd';
    systemctl 'status chronyd';
    assert_script_run 'chronyc tracking';
    assert_script_run 'chronyc waitsync 40 0.01 && chronyc sources', 400;
}

1;

