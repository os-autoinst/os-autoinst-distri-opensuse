# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Public Cloud - VM Configuration and Registration
# This module connects to the Azure VM via SSH and performs:
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
use serial_terminal 'select_serial_terminal';

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
        script_run(join(' ', $args{ssh_command}, 'sudo SUSEConnect --cleanup'), 200);

        my $cmd = join(' ',
            $args{ssh_command},
            qq(sudo registercloudguest --force-new -r "$args{reg_code}" -e testing\@suse.com));
        my $exit = script_run($cmd, 600);
        die "registercloudguest failed with exit $exit" unless ($exit == 0);

        assert_script_run(join(' ', $args{ssh_command}, 'sudo SUSEConnect -s'));
    }

}

sub run {
    my ($self) = @_;

    my $vm_ip = get_required_var('VM_IP');
    my $ssh_cmd = get_required_var('SSH_CMD');
    my $rg = get_required_var('RG');
    my $vm = get_required_var('VM_NAME');

    my $wt = az_vm_wait_running(
        resource_group => $rg,
        name => $vm,
        timeout => 1200);
    my $start_time = time();
    while ((time() - $start_time) < 300) {
        my $ret = script_run("nc -vz -w 1 $vm_ip 22", quiet => 1);
        last if defined($ret) and $ret == 0;
        sleep 10;
    }

    assert_script_run("ssh-keyscan $vm_ip | tee -a ~/.ssh/known_hosts");
    record_info('SSH', 'VM reachable with SSH');

    ensure_system_ready_and_register(reg_code => get_required_var('SCC_REGCODE_SLES4SAP'), ssh_command => $ssh_cmd);
    record_info('Done', 'Test finished');
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
