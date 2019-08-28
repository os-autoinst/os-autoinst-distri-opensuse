# Copyright (C) 2019 SUSE LLC
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

package saltbase;
use base "consoletest";

use strict;
use warnings;

use testapi;
use known_bugs;

use utils qw(zypper_call systemctl);

sub master_prepare {
    # Install the salt master
    zypper_call("in salt-master");

    # Save logs to a directory
    assert_script_run('mkdir -p /var/log/salt');
    assert_script_run('sed -i -e "s/log_file:.*/log_file: \\/var\\/log\\/salt\\/master/" /etc/salt/master');

    # Increese log_level from 'warning' to 'debug'
    assert_script_run('sed -i -e "s/#log_level_logfile:.*/log_level_logfile: debug/" /etc/salt/master');

    # Enable and start the salt-master
    systemctl 'enable salt-master';
    systemctl 'start salt-master';
    systemctl 'status salt-master';

    # Enable event logging
    assert_script_run '( salt-run state.event pretty=True &> /var/log/salt/event & )';
}

sub minion_prepare {
    # Install the salt minion
    zypper_call("in salt-minion");

    # Set the right address of the salt master
    assert_script_run "echo `hostname` > /etc/salt/minion_id";
    if (check_var('HOSTNAME', 'master')) {
        assert_script_run("sed -i -e 's/#master:.*/master: localhost/' /etc/salt/minion");
    } else {
        assert_script_run("sed -i -e 's/#master:.*/master: 10.0.2.101/' /etc/salt/minion");
    }

    # Save logs to a directory
    assert_script_run('sed -i -e "s/log_file:.*/log_file: \\/var\\/log\\/salt\\/minion/" /etc/salt/minion');

    # Increese log_level from 'warning' to 'debug'
    assert_script_run('sed -i -e "s/#log_level_logfile:.*/log_level_logfile: debug/" /etc/salt/minion');

    # Check all the settings we changed
    assert_script_run("grep 'master:\\\|ipv6:\\\|log_' /etc/salt/minion");

    # Enable and start the salt-minion
    systemctl 'enable salt-minion';
    systemctl 'start salt-minion';
    systemctl 'status salt-minion';
}

sub stop {
    if (check_var('HOSTNAME', 'master')) {
        systemctl 'stop salt-master';
    }
    systemctl 'stop salt-minion';
}

=head2 logs_from_salt

Method fetching Salt specific logs.

=cut

sub logs_from_salt {
    if (check_var('HOSTNAME', 'master')) {
        upload_logs '/var/log/salt/master', log_name => 'salt-master.txt';
        upload_logs '/var/log/salt/event',  log_name => 'salt-event.txt';
    }

    upload_logs '/var/log/salt/minion', log_name => 'salt-minion.txt';
}

=head2 post_run_hook

Method executed when run() finishes.

=cut
sub post_run_hook {
    my ($self) = @_;

    # fetch Salt specific logs
    logs_from_salt();

    # start next test in home directory
    type_string "cd\n";

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

=head2 post_fail_hook

Method executed when run() finishes and the module has result => 'fail'

=cut
sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;
    $self->remount_tmp_if_ro;
    $self->export_logs_basic;

    # fetch Salt specific logs
    logs_from_salt();
}

1;
