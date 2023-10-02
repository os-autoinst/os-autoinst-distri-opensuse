# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use base 'sles4sap_publiccloud_basetest';
use testapi;

sub test_flags {
    return {fatal => 1, publiccloud_multi_module => 1};
}

sub run {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);

    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) if get_var('INCIDENT_REPO');
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));
    my $count = 0;

    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        if ($maintrepo =~ /Development-Tools/) {
            record_info("MISSING REPOS", "There are Development-Tools repos in this incident, that are not uploaded to IBSM. Later errors, if they occur, may be due to these.");
            next;
        }
        foreach my $instance (@{$self->{instances}}) {
            next if ($instance->{'instance_id'} !~ m/vmhana/);
            $instance->run_ssh_command(cmd => "sudo zypper --no-gpg-checks ar -f -n TEST_$count $maintrepo TEST_$count",
                username => 'cloudadmin');
        }
        $count++;
    }
    foreach my $instance (@{$self->{instances}}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        $instance->run_ssh_command(cmd => 'sudo zypper -n ref', username => 'cloudadmin', timeout => 1500);
    }
}

1;
