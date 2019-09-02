# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test public cloud SLES4SAP images
#
# Maintainer: Loic Devulder <ldevulder@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use Mojo::JSON;

sub upload_ha_sap_logs {
    my ($self, $instance) = @_;
    my @logfiles = qw(provisioning.log salt-deployment.log salt-formula.log salt-pre-installation.log);

    # Upload logs from public cloud VM
    $instance->run_ssh_command(cmd => 'sudo chmod o+r /tmp/*.log');
    foreach my $file (@logfiles) {
        $instance->upload_log("/tmp/$file", log_name => $instance->{instance_id});
    }
}

sub run {
    my ($self) = @_;

    $self->select_serial_terminal;

    my $provider = $self->provider_factory();
    foreach my $instance ($provider->create_instances(check_connectivity => 1)) {
        $self->upload_ha_sap_logs($instance);
    }
}

1;

=head1 Discussion

This module is used to test public cloud SLES4SAP images.
Logs are uploaded at the end.

=head1 Configuration

=head2 PUBLIC_CLOUD_SLES4SAP

If set, this test module is added to the job.

=head2 PUBLIC_CLOUD_VAULT_NAMESPACE

Set the needed namespace, e.g. B<qa-shap>

=cut
