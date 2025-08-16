# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary:  Executes a crash scenario on azure.
package sles4sap::crash::azure::crash_azure;

use lib 'tests';
use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use sles4sap::azure_cli;
use utils 'script_retry';
use sles4sap::crash::azure::crash_configure;
use sles4sap::crash::azure::crash_deploy;
use sles4sap::crash::azure::crash_destroy;


use constant DEPLOY_PREFIX => 'clne';

sub run {
    my ($self) = @_;

    $self->crash_deploy::run();
    $self->crash_configure::run();

    # Crash test
    my $ssh_cmd = get_required_var('SSH_CMD');
    my $vm_ip = get_required_var('VM_IP');

    ssh_fully_patch_system($ssh_cmd);
    assert_script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'reboot'),
        timeout => 600);
    select_serial_terminal;
    wait_serial(qr/\#/, timeout => 600);

    my $result_crash = script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'bash -c',
            q('"echo b | tee /proc/sysrq-trigger &"')),
        timeout => 30);
    record_info('Crash', 'Triggering crash via SSH command') if defined $result_crash;

    script_retry("nc -zv $vm_ip 22", retry => 10, delay => 45);
    assert_script_run(join(' ',
            $ssh_cmd,
            'sudo',
            'systemctl',
            "--failed"),
        timeout => 600);
    $self->crash_destroy::run();
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
