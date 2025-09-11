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

sub run {
    my ($self) = @_;

    # Crash test
    my $vm_ip = get_required_var('VM_IP');
    my $instance = publiccloud::instance->new(public_ip => $vm_ip, username => 'cloudadmin');
    $instance->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));

    my $max_rounds = 5;
    for my $round (1 .. $max_rounds) {
        record_info("PATCH $round START", "zypper patch round $round");
        my $ret = $instance->run_ssh_command(
            cmd => 'sudo zypper -n patch',
            timeout => 600,
            ssh_opts => '-E /var/tmp/ssh_sut.log -o ServerAliveInterval=2',
            username => 'cloudadmin',
            proceed_on_failure => 1
        );
        record_info("PATCH $round END", "Output:\n$ret");
        last if $ret =~ /Nothing to do|No updates found/;
        if ($ret =~ /SCRIPT_FINISHED.*-103-/) {
            record_info("PATCH $round RE-RUN", "Package manager updated, retrying");
            next;
        }
        die "Patching failed unexpectedly" if $ret =~ /exit code \d+/;
        die "Exceeded $max_rounds patch attempts" if $round == $max_rounds;
    }

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
    my $delay = 10;
    my $start_time = time();
    my ($duration, $exit_code, $sshout, $sysout);
    while (($duration = time() - $start_time) < 300) {
        $exit_code = script_run('nc -vz -w 1 ' . $vm_ip . ' 22', quiet => 1);
        last if ($instance->isok($exit_code));    # ssh port open ok

        sleep $delay;
    }

    my $remote = '-F /dev/null -o ControlMaster=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ' . 'cloudadmin' . '@' . $vm_ip;
    my $services_output = script_output(join(' ', 'ssh', $remote, 'sudo systemctl --failed --no-pager --plain'), 100);
    record_info('Failed services', "Status : $services_output");
    my @failed_units = grep { /^\S+\.(service|socket|target|mount|timer)\s/ } split /\n/, $services_output;
    die "Found failed services:\n$services_output" if @failed_units;
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    az_group_delete(name => get_var('DEPLOY_PREFIX', 'clne') . get_current_job_id(), timeout => 600);
    $self->SUPER::post_fail_hook;
}

1;
