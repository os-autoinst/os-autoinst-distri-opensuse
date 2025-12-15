# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Verify connectivity to the repository mirror
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

qesapdeployment/test_mirror.pm - Verify connectivity to the repository mirror

=head1 DESCRIPTION

Checks if the deployed VMs has been properly configured to be able to use
the internal repository mirror (IBSm).

It uses Ansible to run 'ping' against the mirror's hostname and then refreshes
the 'zypper' repositories to ensure that the package manager can communicate
with the mirrored services.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider.

=item B<QESAPDEPLOY_IBSM_VNET> and B<QESAPDEPLOY_IBSM_RG>

(Azure-specific) VNet and Resource Group of the IBSm. If set, the test logic is executed.

=item B<QESAPDEPLOY_IBSM_PRJ_TAG>

(EC2-specific) The project tag of the IBSm. If set, the test logic is executed.

=item B<QESAPDEPLOY_IBSM_VPC_NAME>, B<IBSM_SUBNET_NAME>, B<IBSM_SUBNET_REGION>, B<IBSM_NCC_HUB>

(GCE-specific) Networking details of the IBSm. If set, the test logic is executed.

=item B<QESAPDEPLOY_DOWNLOAD_HOSTNAME>

The hostname of the repository server (e.g., 'download.suse.de') that is
redirected to the IBSm. This is the target for the 'ping' command.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use sles4sap::qesap::qesapdeployment;
use sles4sap::qesap::aws;

sub run {
    my ($self) = @_;
    my $provider_setting = get_required_var('PUBLIC_CLOUD_PROVIDER');

    if (($provider_setting eq 'AZURE' && get_var('QESAPDEPLOY_IBSM_VNET') && get_var('QESAPDEPLOY_IBSM_RG')) ||
        ($provider_setting eq 'EC2' && get_var('QESAPDEPLOY_IBSM_PRJ_TAG')) ||
        ($provider_setting eq 'GCE' && get_var('QESAPDEPLOY_IBSM_VPC_NAME') && get_var('QESAPDEPLOY_IBSM_SUBNET_NAME') && get_var('QESAPDEPLOY_IBSM_SUBNET_REGION')) ||
        ($provider_setting eq 'GCE' && get_var('QESAPDEPLOY_IBSM_NCC_HUB'))
    ) {
        my @remote_cmd = (
            'ping -c3 ' . get_required_var('QESAPDEPLOY_DOWNLOAD_HOSTNAME'),
            'zypper -n ref -s -f',
            'zypper -n lr');
        qesap_ansible_cmd(cmd => $_, provider => $provider_setting, timeout => 300) for @remote_cmd;
    }
}

sub post_fail_hook {
    my ($self) = shift;
    # This test module does not have the fatal flag.
    # In case of failure, the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
