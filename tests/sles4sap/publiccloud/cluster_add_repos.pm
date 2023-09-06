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

sub run() {
    my ($self, $run_args) = @_;
    my $instance = $run_args->{my_instance};
    $self->{network_peering_present} = 1 if ($run_args->{network_peering_present});
    record_info('CONTEXT LOG', "instance:$instance network_peering_present:$self->{network_peering_present}");

    set_var('MAINT_TEST_REPO', get_var('INCIDENT_REPO')) if get_var('INCIDENT_REPO');
    my $prov = get_required_var('PUBLIC_CLOUD_PROVIDER');
    my @repos = split(/,/, get_var('MAINT_TEST_REPO'));
    my $count = 0;

    while (defined(my $maintrepo = shift @repos)) {
        next if $maintrepo =~ /^\s*$/;
        foreach my $instance (@{$run_args->{instances}}) {
            next if ($instance->{'instance_id'} !~ m/vmhana/);
            $instance->run_ssh_command(cmd => "sudo zypper -n in traceroute", username => 'cloudadmin');
            $instance->run_ssh_command(cmd => "sudo traceroute download.suse.de", username => 'cloudadmin');
            $instance->run_ssh_command(cmd => "sudo zypper --no-gpg-checks ar -f -n TEST_$count $maintrepo TEST_$count",
                username => 'cloudadmin');
        }
        $count++;
    }
    foreach my $instance (@{$run_args->{instances}}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        $instance->run_ssh_command(cmd => "sudo zypper clean --all", username => 'cloudadmin');
        $instance->run_ssh_command(cmd => 'sudo zypper -n ref', username => 'cloudadmin', timeout => 1500);
    }
}

1;
