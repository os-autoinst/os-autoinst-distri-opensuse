# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Destroy all cloud resources created for the test scenario.
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

cloud_netconfig/destroy.pm - Destroy cloud resources for the cloud-netconfig test

=head1 DESCRIPTION

This module is the final cleanup step for the C<cloud-netconfig> test scenario.
Its sole purpose is to destroy all the Azure resources that were provisioned by
C<deploy.pm> to ensure no resources are left running after the test completes.

The module performs the following action:

=over 4

=item * Identifies the Azure resource group associated with the current test job.

=item * Executes the C<az group delete> command to delete the entire resource group

=back

=head1 VARIABLES

=over 4

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider. Currently, only 'AZURE' is supported for this test.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use mmapi 'get_current_job_id';
use serial_terminal 'select_serial_terminal';

use constant DEPLOY_PREFIX => 'clne';

sub run {
    my ($self) = @_;

    die('Azure is the only CSP supported for the moment')
      unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');

    select_serial_terminal;

    my $rg = DEPLOY_PREFIX . get_current_job_id();
    assert_script_run("az group delete --name $rg -y", timeout => 600);
}

sub test_flags {
    return {fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
}

1;
