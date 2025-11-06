# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Public Cloud - VM Configuration and Registration
# This module connects to the VM via SSH and performs:
# - SSH availability check
# - Host key scan and trust
# - (Optional) IBSM repo addition for maintenance update testing
# - SUSEConnect registration using SCC_REGCODE
# - System patching using zypper
# - System reboot
# This prepares the system for crash testing.

use base 'publiccloud::basetest';
use testapi;
use utils;
use sles4sap::azure_cli;
use sles4sap::aws_cli;
use serial_terminal 'select_serial_terminal';
use mmapi 'get_current_job_id';

=head2 ensure_system_ready_and_register

    Polls C<systemctl is-system-running> via SSH for up to 5 minutes.
     If C<reg_code> is provided, registers the system using C<registercloudguest> and verifies with C<SUSEConnect -s>.

=over

=item B<%args> Hash with:

=back

=over

=item B<reg_code> Registration code.

=item B<ssh_command> SSH command for registration.

=back

=cut

sub ensure_system_ready_and_register {
    my (%args) = @_;
    my $start_time = time();
    my $ret;

    while ((time() - $start_time) < 300) {
        $ret = script_run(join(' ', $args{ssh_command}, 'sudo', 'systemctl is-system-running'));
        last unless $ret;
        sleep 10;
    }
    if ($args{reg_code}) {
        script_run(join(' ', $args{ssh_command}, 'sudo SUSEConnect -s'), 200);
        script_run(join(' ', $args{ssh_command}, 'sudo registercloudguest --clean'), 200);

        my $rc = 1;
        my $attempt = 0;

        while ($rc != 0 && $attempt < 4) {
            $rc = script_run("$args{ssh_command} sudo registercloudguest --force-new -r $args{reg_code} -e testing\@suse.com", 600);
            record_info('REGISTER CODE', $rc);
            $attempt++;
        }
        die "registercloudguest failed after $attempt attempts with exit $rc" unless ($rc == 0);
        assert_script_run(join(' ', $args{ssh_command}, 'sudo SUSEConnect -s'));
    }

}

sub run {
    my ($self) = @_;
    my $prefix = get_var('DEPLOY_PREFIX', 'clne');
    my $ssh_cmd = get_required_var('SSH_CMD');
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $job_id = $prefix . get_current_job_id();
    my $vm_ip = '';

    if ($provider eq 'EC2') {
        $vm_ip = aws_get_ip_address(instance_id => aws_vm_get_id(region => get_required_var('PUBLIC_CLOUD_REGION'), job_id => $job_id));
    }
    elsif ($provider eq 'AZURE') {
        $vm_ip = az_network_publicip_get(resource_group => $job_id, name => $prefix . "-pub_ip");
    }

    if (get_required_var('PUBLIC_CLOUD_PROVIDER') eq 'AZURE') {
        my $rg = get_required_var('RG');
        my $vm = get_required_var('VM_NAME');
        az_vm_wait_running(
            resource_group => $rg,
            name => $vm,
            timeout => 1200);
    }

    my $start_time = time();
    while ((time() - $start_time) < 300) {
        my $ret = script_run("nc -vz -w 1 $vm_ip 22", quiet => 1);
        last if defined($ret) and $ret == 0;
        sleep 10;
    }

    assert_script_run("ssh-keyscan $vm_ip | tee -a ~/.ssh/known_hosts");
    record_info('SSH', 'VM reachable with SSH');

    ensure_system_ready_and_register(reg_code => get_var('SCC_REGCODE_SLES4SAP'), ssh_command => $ssh_cmd);
    record_info('Done', 'Test finished');
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
}

1;
