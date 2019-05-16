# Copyright (C) 2015-2019 SUSE LLC
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
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use Utils::Backends 'use_ssh_serial_console';

sub run {
    my $self = shift;
    assert_screen("autoyast-system-login-console", 20);
    # default result
    $self->result('fail');

    # TODO: is_remote_backend could be a better fit here, but not
    # too sure if it would make sense for svirt or s390 for example
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

