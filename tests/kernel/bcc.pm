# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: bpftrace
# Summary: Compile and attach eBPF probes with BCC tools
# Maintainer: kernel-qa@suse.de

use Mojo::Base qw(opensusebasetest);
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    zypper_call('in bcc-tools');

    my $tools_dir = '/usr/share/bcc/tools';

    assert_script_run("$tools_dir/btrfsdist 5 2");
    assert_script_run("$tools_dir/btrfsslower -d 10");
    assert_script_run("$tools_dir/filetop -a 5 10");
}

1;

=head1 Discussion

Smoke test for a small selection of BCC tools.
