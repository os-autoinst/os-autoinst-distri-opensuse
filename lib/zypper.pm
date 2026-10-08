# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package zypper;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi qw(is_serial_terminal :DEFAULT);
use version_utils qw(is_microos is_leap is_sle is_sle12_hdd_in_upgrade is_storage_ng is_jeos);
use Mojo::UserAgent;

our @EXPORT = qw(
  wait_quit_zypper
);

# Process names to poll for (poo#206742, poo#204534); pgrep truncates comm
# to 15 chars, so "transactional-u" stands in for "transactional-update".
use constant BUSY_PROCESS_PATTERN => join('|',
    qw(zypper packagekit purge-kernels rpm snapper transactional-u),
);

=head2 wait_quit_zypper

    wait_quit_zypper();

This function waits for any zypper processes in background to finish.

Some zypper processes (such as purge-kernels) in background hold the lock,
usually it's not intended or common that run 2 zypper tasks at the same time,
so we need wait the zypper processes in background to finish and release the
lock so that we can run a new zypper for our test.

=cut

sub wait_quit_zypper {
    # Short polling commands avoid the serial terminal typing-echo timeout
    # a single long assert_script_run() can hit (poo#206742, poo#204534).
    utils::script_retry('! pgrep \'' . BUSY_PROCESS_PATTERN . '\'', timeout => 20, delay => 10, retry => 120);
}

1;
