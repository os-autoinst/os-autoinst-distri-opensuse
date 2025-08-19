# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Add all additional zypper repositories defined in INCIDENT_REPO
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

cloud_zypper_patch/add_repo.pm - Add additional repositories and register the SUT

=head1 DESCRIPTION

This module performs two main tasks:
- It registers the SUT (System Under Test) with the SUSE Customer Center (SCC)
  if a registration code is provided.
- It adds additional Zypper repositories to the SUT, which are retrieved from
  the IBSM (Infrastructure Build and Support mirror) environment.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. This module currently only supports 'AZURE'.

=item B<SCC_REGCODE_SLES4SAP>

The SUSE Customer Center registration code for SLES for SAP. If provided, the
module will register the SUT.

=item B<REPO_MIRROR_HOST>

The hostname of the repository mirror. Defaults to 'download.suse.de'.

=item B<IBSM_IP>

The IP address of the IBSM server. This is required to add the repositories.

=item B<IBSM_RG>

The name of the Azure Resource Group for the IBSM environment. This is used in
the C<post_fail_hook> to clean up the network peering on failure.

=item B<INCIDENT_REPO>

A comma-separated list of incident-specific repository URLs. This variable is
used by the C<get_test_repos> function to retrieve the list of repositories to
add. Other variables ending with C<_TEST_REPOS> are also considered.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qam 'get_test_repos';
use sles4sap::cloud_zypper_patch;

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    zp_ssh_connect();

    if (get_var('SCC_REGCODE_SLES4SAP')) {
        # Check if somehow the image is already registered or not
        my $is_registered = zp_scc_check();
        record_info('is_registered', $is_registered);
        # Conditionally register the SLES for SAP instance.
        # Registration is attempted only if the instance is not currently registered and a
        # registration code ('SCC_REGCODE_SLES4SAP') is available.
        zp_scc_register(scc_code => get_required_var('SCC_REGCODE_SLES4SAP')) if ($is_registered ne 1);
    }

    my $repo_host = get_var('REPO_MIRROR_HOST', 'download.suse.de');
    my @repos = get_test_repos();
    zp_repos_add(ip => get_required_var('IBSM_IP'),
        name => $repo_host,
        repos => \@repos);
}

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    zp_azure_destroy(ibsm_rg => get_required_var('IBSM_RG'));
    $self->SUPER::post_fail_hook;
}

1;
