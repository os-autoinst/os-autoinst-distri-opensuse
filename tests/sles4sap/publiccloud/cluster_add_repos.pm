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
- For each HANA instance, create a repository file in C</etc/zypp/repos.d/>.
- Refresh zypper on all modified instances.

=head1 SETTINGS

=over

=item B<INCIDENT_REPO>

Comma-separated list of repository URLs to add.

=item B<REPO_PRIORITY>

Optional priority to set for the added repositories.

=back

=head1 MAINTAINER

QE-SAP <qe-sap@suse.de>

=cut

use base 'sles4sap::sles4sap_publiccloud_basetest';
use sles4sap::sles4sap_publiccloud;
use qam;
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);
    my @repos = get_test_repos();
    my $count = 0;

    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        if ($maintrepo =~ /Development-Tools/ or $maintrepo =~ /Desktop-Applications/) {
            record_info("MISSING REPOS", "There are repos in this incident, that are not uploaded to IBSM. ($maintrepo). Later errors, if they occur, may be due to these.");
            next;
        }
        foreach my $instance (@{$self->{instances}}) {
            next if ($instance->{'instance_id'} !~ m/vmhana/);
            # Create repository file on target
            my $reponame = "TEST_$count";
            my @content = ("[$reponame]", "name=$reponame", "enabled=1", "autorefresh=1", "baseurl=$maintrepo");
            push @content, "priority=" . get_var('REPO_PRIORITY') if get_var('REPO_PRIORITY');
            # tricky quoting: the echoed @content needs to be inside double quotes " "
            # and newline separator is single quoted so won't be interpreted by Perl
            my $command = 'echo -e "' . join('\n', @content) . qq{" | sudo tee /etc/zypp/repos.d/$reponame.repo};
            $instance->ssh_assert_script_run(cmd => $command, username => 'cloudadmin');
        }
        $count++;
    }
    foreach my $instance (@{$self->{instances}}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        $self->wait_for_zypper(instance => $instance);
        $instance->ssh_assert_script_run(cmd => 'sudo zypper -n ref', username => 'cloudadmin', timeout => 1500);
    }
}

1;
