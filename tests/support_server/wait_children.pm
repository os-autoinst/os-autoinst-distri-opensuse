# Copyright (C) 2015-2018 SUSE Linux GmbH
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

# Summary: Main purpose not allow support server to go down
# until all parallel jobs finish what they are doing
# Maintainer: Pavel Sladek <psladek@suse.com>

use strict;
use warnings;
use base 'basetest';
use testapi;
use mmapi;

sub run {
    my $self = shift;

    select_console 'root-console';
    # We don't need any logs from support server when running on REMOTE_CONTROLLER for remote SLE installation tests
    type_string("journalctl -f |tee /dev/$serialdev\n") unless (get_var('REMOTE_CONTROLLER'));

    wait_for_children;

    unless (get_var('REMOTE_CONTROLLER')) {
        send_key 'ctrl-c';

        my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
        my %server_roles = map { $_ => 1 } @server_roles;

        # No messages file in openSUSE which use journal by default
        # Write journal log to /var/log/messages for openSUSE
        if (check_var('DISTRI', 'opensuse')) {
            script_run 'journalctl -b -x > /var/log/messages', 90;
        }
        my $log_cmd = "tar cjf /tmp/logs.tar.bz2 /var/log/messages ";
        if (exists $server_roles{qemuproxy} || exists $server_roles{aytest}) {
            $log_cmd .= "/var/log/apache2 ";
        }
        assert_script_run $log_cmd;
        upload_logs "/tmp/logs.tar.bz2";
    }
    $self->result('ok');
}


sub test_flags {
    return {fatal => 1};
}

1;
