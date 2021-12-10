# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pacemaker-cli crmsh csync2
# Summary: Test public cloud SLES4SAP images
#
# Maintainer: Loic Devulder <ldevulder@suse.de>

use strict;
use warnings;
use Mojo::Base qw(publiccloud::basetest publiccloud::ssh_interactive_init);
use testapi;
use Mojo::File 'path';
use Mojo::JSON qw(to_json encode_json);
use sles4sap_publiccloud;
use Data::Dumper;

sub test_flags {
    return {
        fatal => 1,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

sub run {
    my ($self, $run_args) = @_;
    my $timeout = 120;
    my @cluster_types = split(',', get_required_var('CLUSTER_TYPES'));

    $self->select_serial_terminal;

    my $provider = $self->provider_factory();
    my @instances = $provider->create_instances(check_connectivity => 1);
    my @instances_export;

    # Upload all TF/SALT logs first!

    foreach my $instance (@instances) {
        $self->upload_ha_sap_logs($instance);
        push(@instances_export, $instance);
    }

    $run_args->{instances} = \@instances_export;
    record_info("All inst dump", \@instances_export);
    my $datadump = Dumper(@instances);
    run_cmd("echo $datadump > /tmp/instances.pl");
    upload_logs("/tmp/instances.pl");

    foreach my $instance (@instances) {
        record_info("instance dump", Dumper($instance));
        $self->{my_instance} = $instance;
        # Get the hostname of the VM, it contains the cluster type
        my $hostname = $self->run_cmd(cmd => 'uname -n', quiet => 1);

        foreach my $cluster_type (@cluster_types) {
            # Some actions are done only on the first node of each cluster
            if ($hostname =~ m/${cluster_type}01$/) {
                if ($cluster_type eq 'hana') {
                    # Before doing anything on the cluster we have to wait for the HANA sync to be done
                    $self->run_cmd(cmd => 'sh -c \'until SAPHanaSR-showAttr | grep -q SOK; do sleep 1; done\'', timeout => $timeout, quiet => 1);
                    # Show HANA replication state
                    $self->run_cmd(cmd => 'SAPHanaSR-showAttr');
                }

                # Wait for all resources to be up
                # We need to be sure that the cluster is OK before a fencing test
                record_info('Cluster type', $cluster_type);
                $self->wait_until_resources_started(cluster_type => $cluster_type, timeout => $timeout);
            }
        }
        record_info("$hostname created")
    }
}

1;