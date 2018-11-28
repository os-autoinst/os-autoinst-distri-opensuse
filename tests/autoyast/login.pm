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

# Summary: Log into system installed with autoyast
# Maintainer: Pavel Sladek <psladek@suse.cz>

use strict;
use base 'y2logsstep';
use testapi;
# TODO: is_remote_backend we need to ensure if for autoyast we want this or
# this also applies for other backends
use Utils::Backends qw (use_ssh_serial_console is_remote_backend);

sub run {
    my $self = shift;
    assert_screen("autoyast-system-login-console", 20);
    $self->result('fail');    # default result
    if (check_var('BACKEND', 'ipmi')) {
        #use console based on ssh to avoid unstable ipmi
        use_ssh_serial_console;
    }
    assert_script_run 'echo "checking serial port"';
    type_string "cat /proc/cmdline\n";
    save_screenshot;
    $self->result('ok');
}

sub test_flags {
    return {fatal => 1};
}

1;

