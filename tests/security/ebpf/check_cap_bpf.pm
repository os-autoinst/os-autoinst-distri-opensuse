# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'CAP_BPF' capability is available:
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#103932, tc#1769831

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $f_tcpdump = '/usr/sbin/tcpdump';
    my $capability = 'cap_bpf';

    select_console 'root-console';

    # Install packages
    zypper_call('in libcap-progs tcpdump');

    assert_script_run("getcap $f_tcpdump");
    assert_script_run("setcap $capability+eip $f_tcpdump");
    validate_script_output("getcap $f_tcpdump", sub { m/.*$capability.*/ });
}

1;
