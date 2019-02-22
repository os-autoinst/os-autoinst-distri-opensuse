# Copyright (C) 2015-2018 SUSE LLC
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

use base Exporter;
use Exporter;
use strict;
use testapi;
use main_common;
use version_utils;

our @EXPORT = qw(
  create_list_of_serial_failures
);

sub create_list_of_serial_failures {
    my $serial_failures = [];

    # To add a known bug simply copy and adapt the following line:
    # push @$serial_failures, {type => soft/hard, message => 'Errormsg', pattern => quotemeta 'ErrorPattern' }


    # Detect rogue workqueue lockup
    push @$serial_failures, {type => 'hard', message => 'rogue workqueue lockup', pattern => quotemeta 'BUG: workqueue lockup'};

    # Detect bsc#1093797 on aarch64
    if (is_sle('=12-SP4') && check_var('ARCH', 'aarch64')) {
        push @$serial_failures, {type => 'hard', message => 'bsc#1093797', pattern => quotemeta 'Internal error: Oops: 96000006'};
    }

    push @$serial_failures, {type => 'soft', message => 'bsc#1112109', pattern => qr/serial-getty.*service: Service hold-off time over, scheduling restart/};

    if (is_kernel_test()) {
        my $type = is_ltp_test() ? 'soft' : 'hard';
        push @$serial_failures, {type => $type, message => 'Kernel Ooops found',             pattern => quotemeta 'Oops:'};
        push @$serial_failures, {type => $type, message => 'Kernel BUG found',               pattern => qr/kernel BUG at/i};
        push @$serial_failures, {type => $type, message => 'WARNING CPU in kernel messages', pattern => quotemeta 'WARNING: CPU'};
        push @$serial_failures, {type => $type, message => 'Kernel stack is corrupted',      pattern => quotemeta 'stack-protector: Kernel stack is corrupted'};
        push @$serial_failures, {type => $type, message => 'Kernel BUG found',               pattern => quotemeta 'BUG: failure at'};
        push @$serial_failures, {type => $type, message => 'Kernel Ooops found',             pattern => quotemeta '-[ cut here ]-'};
    }


    # Disable CPU soft lockup detection on aarch64 until https://progress.opensuse.org/issues/46502 get resolved
    push @$serial_failures, {type => 'hard', message => 'CPU soft lockup detected', pattern => quotemeta 'soft lockup - CPU'} unless check_var('ARCH', 'aarch64');

    return $serial_failures;
}

1;
