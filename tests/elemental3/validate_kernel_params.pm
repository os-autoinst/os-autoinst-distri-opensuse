# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: validate that kernel parameters are correctly added to the OS image
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;
    my $krnlcmdline = get_required_var('KERNEL_CMD_LINE');

    select_serial_terminal();

    record_info('Kernel Parameters', "Validate kernel parameters: '$krnlcmdline'");
    assert_script_run("grep -q '$krnlcmdline' /proc/cmdline");
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
