# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: nmap iputils bind-utils
# Summary: This test prepares environment
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;
use version_utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    script_run("SUSEConnect -r " . get_var('SCC_REGCODE'), timeout => 420);

    assert_script_run "rm /etc/zypp/repos.d/SUSE_Maintenance* || true";
    assert_script_run "rm /etc/zypp/repos.d/TEST* || true";
    zypper_call '-t in nmap iputils bind-utils', exitcode => [0, 102, 103, 106];

    # Fill the current pairs of hostname & address into /etc/hosts file
    assert_script_run "echo \"\$(dig +short $virt_autotest::common::guests{$_}->{ip}) $_ # virtualization\" >> /etc/hosts" foreach (keys %virt_autotest::common::guests);
    assert_script_run "cat /etc/hosts";
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

