# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Add IBSM mapping to /etc/hosts on HANA instances
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/add_server_to_hosts.pm - Add IBSM mapping to /etc/hosts on HANA instances

=head1 DESCRIPTION

This module iterates through all the SUT. For each `vmhana` VM, it updates the `/etc/hosts` file.

Its primary tasks are:

- Identify HANA instances (vmhana).
- Append the mapping of `IBSM_IP` to `REPO_MIRROR_HOST` in `/etc/hosts`.
- Verify the change by displaying `/etc/hosts`.

=head1 SETTINGS

=over

=item B<REPO_MIRROR_HOST>

The hostname of the repository mirror. Defaults to 'download.suse.de'.

=item B<IBSM_IP>

The IP address of the IBSM (Internal Build Service Mirror) or repository server. Required.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap::publiccloud_basetest';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);

    foreach my $instance (@{$self->{instances}}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        record_info("$instance");

        my $repo_host = get_var('REPO_MIRROR_HOST', 'download.suse.de');
        my $ibsm_ip = get_required_var('IBSM_IP');
        $instance->ssh_assert_script_run(cmd => "echo \"$ibsm_ip $repo_host\" | sudo tee -a /etc/hosts", username => 'cloudadmin');
        $instance->ssh_assert_script_run(cmd => 'cat /etc/hosts', username => 'cloudadmin');
    }
}

1;
