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
    my $instances = $run_args->{instances};
    $self->{network_peering_present} = 1 if ($run_args->{network_peering_present});
    record_info('CONTEXT LOG', "instances:$instances network_peering_present:$self->{network_peering_present}");

    foreach my $instance (@{$instances}) {
        next if ($instance->{'instance_id'} !~ m/vmhana/);
        record_info("$instance");

        my $ibsm_ip = get_required_var('IBSM_IP');
        $instance->run_ssh_command(cmd => "echo \"$ibsm_ip download.suse.de\" | sudo tee -a /etc/hosts", username => 'cloudadmin');
        $instance->run_ssh_command(cmd => 'cat /etc/hosts', username => 'cloudadmin');
        #$instance->run_ssh_command(cmd => "ping -c 4 download.suse.de", username => 'cloudadmin');
    }
}

1;
