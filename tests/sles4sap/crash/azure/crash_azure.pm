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
    my $vm_ip = get_required_var('VM_IP');
    my $instance = publiccloud::instance->new(public_ip => $vm_ip, username => 'cloudadmin');

    record_info('PATCH', 'Fully patch system start');
    my $remote = '-o ControlMaster=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ' . 'cloudadmin' . '@' . $vm_ip;
    ssh_fully_patch_system($remote);
    $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    select_serial_terminal;
    wait_serial(qr/\#/, timeout => 600);

    $instance->run_ssh_command(
        cmd => 'sudo su -c "echo b > /proc/sysrq-trigger &"',
        timeout => 10,
        rc_only => 1,
        ssh_opts => '-E /var/tmp/ssh_sut.log -fn -o ServerAliveInterval=2',
        username => 'cloudadmin');

    record_info('Wait until', 'Wait until SUT is back again');
    my $start_time = time();
    my $ret;
    while ((time() - $start_time) < 300) {
        $ret = script_output("ssh -o StrictHostKeyChecking=no cloudadmin\@$vm_ip 'nc -vz -w 2 $vm_ip 22'", quiet => 1);
        record_info('NC', $ret);
        last if defined($ret) and $ret =~ /22 port \[tcp\/ssh\] succeeded!/;
        sleep 10;
    }
    my $services_output = script_output(join(' ', 'ssh', $remote, 'sudo systemctl --failed --no-pager --plain'), 100);
    record_info('Failed services', "Service status : $services_output");
    my @failed_units = grep { /^\S+\.(service|socket|target|mount|timer)\s/ } split /\n/, $services_output;
    die "Found failed services:\n$services_output" if @failed_units;
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
