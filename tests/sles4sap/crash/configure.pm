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
use testapi;
use utils;
use sles4sap::azure_cli;
use sles4sap::aws_cli;
use sles4sap::crash;
use serial_terminal 'select_serial_terminal';

sub run {
    my ($self) = @_;

    my $provider = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my $ssh_cmd;
    my $vm_ip = crash_pubip(provider => $provider, region => get_var('PUBLIC_CLOUD_REGION'));

    if ($provider eq 'EC2') {
        $ssh_cmd = "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user\@$vm_ip";
    }
    elsif ($provider eq 'AZURE') {
        $ssh_cmd = 'ssh cloudadmin@' . $vm_ip;
    }

    my $start_time = time();
    while ((time() - $start_time) < 300) {
        my $ret = script_run("nc -vz -w 1 $vm_ip 22", quiet => 1);
        last if defined($ret) and $ret == 0;
        sleep 10;
    }

    assert_script_run("ssh-keyscan $vm_ip | tee -a ~/.ssh/known_hosts");
    crash_system_ready(
        reg_code => get_var('SCC_REGCODE_SLES4SAP'),
        ssh_command => $ssh_cmd);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
}

1;
