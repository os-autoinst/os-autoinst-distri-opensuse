# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: ha-cluster-bootstrap
# Summary: Remove a node both by its hostname and ip address
# Maintainer: Julien Adamek <jadamek@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use sles4sap_publiccloud;
use publiccloud::utils;
use Data::Dumper;
use Storable;

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
    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    my $instances_export_path = get_var("INSTANCES_EXPORT");
    my $skip_deployment = get_var('INSTANCES_IMPORT');

    $self->select_serial_terminal;

    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    if (defined($skip_deployment) and length($skip_deployment)){
        assert_script_run("ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa");
        copy_ssh_keys();
        return;
    }

    my $provider = $self->provider_factory();

    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    if (defined($instances_export_path) and length($instances_export_path)) {
        copy_ssh_keys();
    }

    my @instances = $provider->create_instances(check_connectivity => 1);
    my @instances_export;

    # Upload all TF/SALT logs first!

    foreach my $instance (@instances) {
        $self->upload_ha_sap_logs($instance);
        print(Dumper($instance));
        push(@instances_export, $instance);
    }

    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    print(Dumper(@instances));
    # Mostly for dev - for reusing deployed instances, load this file.
    if (defined($instances_export_path) and length($instances_export_path)){
        record_info('Exporting data', Dumper(@instances_export));
        record_info('Export path', Dumper($instances_export_path));
        store(\@instances_export, $instances_export_path);
    }
    else{
        record_info('NOT exporting data');
    }

    $run_args->{instances} = \@instances_export;

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

=head2 copy_ssh_keys

Copies static ssh keys stored in /data/sls4sap/. Mostly for development purposes, most probably unsecure.

=cut
sub copy_ssh_keys{
    foreach my $file ("id_rsa", "id_rsa.pub"){
        assert_script_run("mkdir -p /root/.ssh");
        assert_script_run("curl -f -v " . data_url("sles4sap/$file") . " -o /root/.ssh/$file");
        assert_script_run("chmod 700 /root/.ssh/$file");
    }
}

1;