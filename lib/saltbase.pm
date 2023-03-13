# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

package saltbase;
use base "consoletest";

use strict;
use warnings;

use testapi;
use known_bugs;

use utils qw(zypper_call systemctl remount_tmp_if_ro);

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

    assert_script_run("grep -B9 -A9 'disable_modules' /etc/salt/minion");
    assert_script_run("echo -en 'disable_modules:\n  - boto3_elasticsearch\n' >> /etc/salt/minion");
    assert_script_run("grep -B9 -A9 'disable_modules' /etc/salt/minion");
    upload_logs '/etc/salt/minion';

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
    assert_script_run "ls /var/log/salt";

    if (check_var('HOSTNAME', 'master')) {
        upload_logs '/var/log/salt/master', log_name => 'salt-master.txt';
        upload_logs '/var/log/salt/event', log_name => 'salt-event.txt';
    }

    upload_logs '/var/log/salt/minion', log_name => 'salt-minion.txt';

    my $error = "cat /var/log/salt/* | grep -i '\\[.*CRITICAL.*\\]\\|\\[.*ERROR.*\\]\\|Traceback' ";
    $error .= "| grep -vi 'Error while parsing IPv\\|Error loading module\\|Unable to resolve address\\|SaltReqTimeoutError' ";
    $error .= "| grep -vi 'has cached the public key for this node\\|Minion unable to successfully connect to a Salt Master'";
    $error .= "| grep -vi 'Error while bringing up minion for multi-master'";
    if (script_run("$error") != 1) {
        die "Salt logs are containing errors!";
    }
}

=head2 post_run_hook

Method executed when run() finishes.

=cut

sub post_run_hook {
    my ($self) = @_;

    # fetch Salt specific logs
    logs_from_salt();

    # Stop both master and minion at the end
    stop();

    # start next test in home directory
    enter_cmd "cd";

    # clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

=head2 post_fail_hook

Method executed when run() finishes and the module has result => 'fail'

=cut

sub post_fail_hook {
    my ($self) = shift;
    return if get_var('NOLOGS');
    select_console('log-console');

    # fetch Salt specific logs
    logs_from_salt();

    # Stop both master and minion at the end
    stop();

    $self->SUPER::post_fail_hook;
    remount_tmp_if_ro;
}

1;
