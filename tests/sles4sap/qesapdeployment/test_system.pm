# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Perform basic OS-level sanity checks
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

qesapdeployment/test_system.pm - Perform basic OS-level sanity checks

=head1 DESCRIPTION

Series of basic operating system and package management checks on
the SUT. It uses Ansible to execute commands on the remote nodes.

The checks include:
- Verifying the OS release information ('/etc/os-release').
- Checking the SUSEConnect registration status.
- Refreshing zypper repositories and listing them.
- Attempting to install packages ('vim', 'ClusterTools2') to ensure the
  package manager is functional.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider, which is required for locating the
inventory and running Ansible commands.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use sles4sap::qesap::qesapdeployment;

sub run {
    my ($self) = @_;
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    # Ignore return, just test the mechanism to find the inventory
    qesap_get_inventory(provider => $provider_setting);

    my $chdir = qesap_get_terraform_dir(provider => $provider_setting);
    assert_script_run("terraform -chdir=$chdir output");
    my @remote_cmd = (
        'pwd', 'uname -a',
        'cat /etc/os-release',
        'sudo SUSEConnect --status-text',
        'zypper -n ref -s -f', 'zypper -n lr',
        'zypper -n in -f -y vim',
        'zypper -n in -y ClusterTools2'
    );
    qesap_ansible_cmd(cmd => $_, provider => $provider_setting, timeout => 300) for @remote_cmd;
}

sub post_fail_hook {
    my ($self) = shift;
    # This test module does not have the fatal flag.
    # In case of failure, the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
