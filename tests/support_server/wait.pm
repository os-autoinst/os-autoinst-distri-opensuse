# Copyright (C) 2015 SUSE Linux GmbH
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

use strict;
use base 'basetest';
use testapi;
use mmapi;

sub run {
    my $self = shift;

    type_string("journalctl -f |tee /dev/$serialdev\n");

    wait_for_children;

    send_key("ctrl-c");

    my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
    my %server_roles = map { $_ => 1 } @server_roles;

    my $log_cmd = "tar cjf /tmp/logs.tar.bz2 /var/log/messages ";
    if (exists $server_roles{qemuproxy} || exists $server_roles{aytest}) {
        $log_cmd .= "/var/log/apache2 ";
    }
    assert_script_run $log_cmd;
    upload_logs "/tmp/logs.tar.bz2";

    $self->result('ok');
}


sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;
