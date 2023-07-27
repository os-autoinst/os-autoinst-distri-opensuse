# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: prepare the VM to sync with the ansible_target
# Maintainer: qa-c@suse.de

use base "consoletest";
use serial_terminal 'select_serial_terminal';
use transactional qw(trup_call process_reboot);
#use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use mm_network qw(setup_static_mm_network);
use utils qw(zypper_call);

sub run {
    my ($self, $args) = @_;
    select_serial_terminal;

    record_info('system', script_output('cat /etc/os-release'));
    # setup_static_network(ip => '10.0.2.15/15', gw => '10.0.2.2');
    # record_info('ip', script_output('ip a'));
    # record_info('route', script_output('ip r'));
    # assert_script_run('echo "10.0.2.20  microos" >> /etc/hosts');
    # zypper_call('in -y iputils git');

    setup_static_mm_network('10.0.2.15/15');

    record_info('ip', script_output('ip a'));
    record_info('route', script_output('ip r'));
    script_run('ping -c 1 download.suse.de');

    assert_script_run('curl -f -v ' . autoinst_url . '/data/slenkins/ssh/id_rsa > /root/.ssh/id_rsa');
    assert_script_run('chmod 600 /root/.ssh/id_rsa');

    my $children = get_children();
    my $child_id = (keys %$children)[0];
    mutex_wait('target_is_ready', $child_id);

    # Testing target is accessible
    assert_script_run('ping -c 1 microos');
    assert_script_run('ssh -v -o StrictHostKeyChecking=accept-new root@microos cat /etc/os-release');

    mutex_create 'job_completed';

    wait_for_children;
}

1;
