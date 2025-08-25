# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executes a crash scenario on azure.

use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use sles4sap::azure_cli;
use publiccloud::instance;
use utils;

use constant DEPLOY_PREFIX => 'clne';

sub run {
    my ($self) = @_;

    # Crash test
    my $ssh_cmd = get_required_var('SSH_CMD');
    my $vm_ip = get_required_var('VM_IP');
    my $instance = publiccloud::instance->new(public_ip => $vm_ip);

    record_info('PATCH', 'Fully patch system start');
    my $remote = '-o ControlMaster=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ' . 'cloudadmin' . '@' . $vm_ip;
    ssh_fully_patch_system($remote);
    assert_script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'reboot'),
        timeout => 600);
    select_serial_terminal;
    wait_serial(qr/\#/, timeout => 600);

    $instance->run_ssh_command(
        cmd => 'sudo su -c "echo b > /proc/sysrq-trigger &"',
        timeout => 10,
        rc_only => 1,
        ssh_opts => ' -E /var/tmp/ssh_sut.log -fn -o ServerAliveInterval=2',
        username => 'cloudadmin');
    record_info('Wait ssh disappear', 'START');

    $instance->ssh_script_retry(cmd => $ssh_cmd . 'nc -zv ' . $vm_ip . ' 22', timeout => 300, retry => 10, delay => 45);
    assert_script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'systemctl',
            "--failed"),
        timeout => 600);
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    az_group_delete(name => DEPLOY_PREFIX . get_current_job_id(), timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
