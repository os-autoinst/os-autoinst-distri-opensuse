# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Verify serial console redirection to cluster nodes
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

qesapdeployment/test_console_redirection.pm - Verify serial console redirection to cluster nodes

=head1 DESCRIPTION

Tests the ability to talk to SUT using console redirection
For each host, it establishes a serial console connection,
runs a basic command ('hostname') to confirm successful redirection, and then
disconnects.

=head1 SETTINGS

=over

=item B<PUBLIC_CLOUD_PROVIDER>

Specifies the public cloud provider, which is required to locate the correct
Ansible inventory file.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'publiccloud::basetest';
use testapi;
use sles4sap::qesap::qesapdeployment;
use sles4sap::console_redirection;
use YAML::PP;

sub run {
    my ($self) = @_;

    my $ypp = YAML::PP->new;
    my $raw_file = script_output('cat ' . qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER')));
    my $inventory_data = $ypp->load_string($raw_file)->{all}{children};

    for my $hostname (keys %{$inventory_data->{hana}{hosts}}) {
        next unless $hostname =~ /vmhana/;
        connect_target_to_serial(
            destination_ip => $inventory_data->{hana}{hosts}{$hostname}{ansible_host},
            ssh_user => 'cloudadmin',
            switch_root => 1);

        die "Redirection to $hostname is not active" unless check_serial_redirection();
        script_run('hostname');

        disconnect_target_from_serial();
    }
    die "Redirection is still active" if check_serial_redirection();
}

sub post_fail_hook {
    my ($self) = shift;
    disconnect_target_from_serial();
    # This test module does not have the fatal flag.
    # In case of failure, the next test_ module is executed too.
    # Deployment destroy is delegated to the destroy test module
    $self->SUPER::post_fail_hook;
}

1;
