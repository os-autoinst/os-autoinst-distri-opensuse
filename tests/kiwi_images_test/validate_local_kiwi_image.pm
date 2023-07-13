# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate the locally built Kiwi qcow2 image by booting it.
# Maintainer:  QE Core <qe-core@suse.de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    my $args_gw = testapi::host_ip();
    select_serial_terminal;
    assert_script_run("cat /etc/os-release");
    assert_script_run("ip a");
    assert_script_run('ping -c 1 ' . $args_gw);
}

1;
