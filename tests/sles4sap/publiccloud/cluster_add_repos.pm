# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Add incident repositories to HANA cluster instances
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 NAME

sles4sap/publiccloud/cluster_add_repos.pm - Add incident repositories to HANA cluster instances

=head1 DESCRIPTION

This module adds maintenance repositories to the HANA cluster instances (matching 'vmhana').

Its primary tasks are:

- Retrieve the list of test repositories (from C<INCIDENT_REPO>).
- Filter out repositories that are not uploaded to IBSM (e.g., Development-Tools, Desktop-Applications).
- For each HANA instance, use zypper addrepo to add the test repositories.
- Refresh zypper on all modified instances.

=head1 SETTINGS

=over

=item B<INCIDENT_REPO>

Comma-separated list of repository URLs to add.

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use Mojo::Base 'sles4sap::publiccloud_basetest';
use sles4sap::publiccloud;
use publiccloud::utils qw(zypper_call_remote);
use qam;
use testapi;

sub test_flags {
    return {fatal => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);
    my @repos = get_test_repos();

    my $repo_index = 0;
    foreach my $repo (@repos) {
        next if $repo =~ /^\s*$/;
        if ($repo =~ /Development-Tools/ or $repo =~ /Desktop-Applications/) {
            record_info("MISSING REPOS", "There are repos in this incident, that are not uploaded to IBSM. ($repo). Later errors, if they occur, may be due to these.");
            next;
        }
        foreach my $instance (@{$self->{instances}}) {
            next if ($instance->{'instance_id'} !~ m/vmhana/);
            zypper_call_remote($instance, cmd => "addrepo $repo TEST_$repo_index", timeout => 240, retry => 6, delay => 60);
        }
        $repo_index++;
    }
    foreach my $instance (@{$self->{instances}}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        zypper_call_remote($instance, cmd => " --gpg-auto-import-keys ref", timeout => 240, retry => 6, delay => 60);
    }
}

1;
