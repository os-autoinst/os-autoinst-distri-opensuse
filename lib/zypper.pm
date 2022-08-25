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

=head2 wait_quit_zypper

    wait_quit_zypper();

This function waits for any zypper processes in background to finish.

Some zypper processes (such as purge-kernels) in background hold the lock,
usually it's not intended or common that run 2 zypper tasks at the same time,
so we need wait the zypper processes in background to finish and release the
lock so that we can run a new zypper for our test.

=cut

sub wait_quit_zypper {
    # sometimes the zypper processes already in quit process but can't pgrep, we
    # need wait several seconds for them to finish deactivate.
    assert_script_run('for ((i=60; i>0; i--)) do if (! pgrep \'zypper|purge-kernels|rpm\' > /dev/null); then sleep 20; break; else sleep 10; continue; fi done', 600);
}

1;
