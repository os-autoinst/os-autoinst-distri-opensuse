# Copyright (C) 2014-2018 SUSE LLC
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


use base "y2_module_guitest";
use strict;
use testapi;

sub run {
    my $self = shift;

    select_console 'root-console';
#   assert_script_run 'echo Hello World!';
#   assert_script_run 'ls -l';
#   assert_script_run 'ip a';
#   assert_script_run 'systemctl stop firewalld';
#   assert_script_run 'systemctl start sshd.service';
    assert_script_run 'zypper -n in tftp yast2-tftp-server', 200;
    script_run 'systemctl status tftp.socket';

    select_console 'x11';
    $self->launch_yast2_module_x11('tftp-server', match_timeout => 60);
    send_key "alt-n";
    assert_screen "yast2_tftp_server_enabled";# here is the tag name of the needle.
    send_key "alt-o";    # OK => Exit

    select_console 'root-console';
    assert_script_run 'systemctl status tftp.socket';
    assert_screen "yast2_tftp_server_check_socket";  
    assert_script_run 'chmod 777 /srv/tftpboot';
    assert_script_run 'echo "hello world" > /srv/tftpboot/tmp.txt';
    assert_script_run 'chmod 777 /srv/tftpboot/tmp.txt';
    assert_script_run 'tftp -v 127.0.0.1 -c get tmp.txt';
    assert_script_run 'tftp -v 127.0.0.1 -c put tmp.txt';
    assert_screen "yast2_tftp_server_result";  
    select_console 'x11';
}

1;
