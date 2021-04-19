# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

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
    assert_script_run('until ! pgrep \'zypper|purge-kernels|rpm\' > /dev/null; do sleep 10; done', 600);
}

1;
