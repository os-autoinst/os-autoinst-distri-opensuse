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

use Mojo::Base 'publiccloud::basetest';
use serial_terminal 'select_serial_terminal';
use testapi;
use sles4sap::crash;
use publiccloud::utils qw(register_addon);

sub run {
    my ($self) = @_;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $vm_ip = crash_pubip(provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'));

    my $remote_host;
    if ($provider eq 'EC2') {
        $remote_host = "-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user\@$vm_ip";
    }
    elsif ($provider eq 'AZURE') {
        $remote_host = 'cloudadmin@' . $vm_ip;
    }
    my $ssh_cmd = "ssh $remote_host";

    my $start_time = time();
    while ((time() - $start_time) < 300) {
        my $ret = script_run("nc -vz -w 1 $vm_ip 22", quiet => 1);
        last if defined($ret) and $ret == 0;
        sleep 10;
    }

    assert_script_run("ssh-keyscan $vm_ip | tee -a ~/.ssh/known_hosts");
    crash_system_ready(
        reg_code => get_var('SCC_REGCODE_SLES4SAP'),
        ssh_command => $ssh_cmd,
        scc_endpoint => get_var('PUBLIC_CLOUD_SCC_ENDPOINT', undef));

    if (my $addons = get_var('SCC_ADDONS')) {
        register_addon($remote_host, $_) foreach (split(',', $addons));
    }
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    if ($provider eq 'AZURE') {
        crash_destroy_azure();
    }
    elsif ($provider eq 'EC2') {
        crash_destroy_aws(region => get_required_var('PUBLIC_CLOUD_REGION'));
    }
    $self->SUPER::post_fail_hook;
}

1;
