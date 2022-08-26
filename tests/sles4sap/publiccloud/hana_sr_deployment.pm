# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

# Summary: Deploy SAP Hana cluster with system replication and verify working cluster.


use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use Mojo::File 'path';
use sles4sap_publiccloud;
use publiccloud::utils;
use qesapdeployment;
use Data::Dumper;
use Storable;
use Mojo::JSON qw(decode_json encode_json);

sub test_flags {
    return {
        fatal => 1,
        milestone => 0,
        publiccloud_multi_module => 1
    };
}

=head3 qesap_get_variables

    Create a hash of variables and a list of required vars to replace in yaml config.
    Values are taken either from ones defined in openqa ("value") or ("default") values within this function.
    Openqa value takes precedence.
=cut
sub qesap_get_variables {
    my %variables;
    $variables{HANA_SAR} = get_required_var("HANA_SAR");
    $variables{REGION} = get_required_var("PUBLIC_CLOUD_REGION");
    $variables{HANA_CLIENT_SAR} = get_required_var("HANA_CLIENT_SAR");
    $variables{HANA_SAPCAR} = get_required_var("HANA_SAPCAR");
    $variables{SCC_REGCODE_SLES4SAP} = get_required_var("SCC_REGCODE_SLES4SAP");
    $variables{STORAGE_ACCOUNT_NAME} = get_var("STORAGE_ACCOUNT_NAME");
    $variables{STORAGE_ACCOUNT_KEY} = get_var("STORAGE_ACCOUNT_KEY");
    $variables{PUBLIC_CLOUD_RESOURCE_NAME} = get_var("PUBLIC_CLOUD_RESOURCE_NAME");
    $variables{FENCING_MECHANISM} = get_var("FENCING_MECHANISM", "sbd");

    return(%variables);
}

sub run {
    my ($self, $run_args) = @_;
    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    my $instances_import_path = get_var("INSTANCES_IMPORT");
    my $instances_export_path = get_var("INSTANCES_EXPORT");
    my $skip_deployment = get_var('INSTANCES_IMPORT');
    my %variables = qesap_get_variables();

    $self->select_serial_terminal;

    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    if (defined($skip_deployment) and length($skip_deployment)){
        assert_script_run("ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa");
        copy_ssh_keys();
        $self->{instances} = $run_args->{instances} = retrieve($instances_import_path);
        $self->identify_instances();
        $run_args->{site_a} = $self->{site_a};
        $run_args->{site_b} = $self->{site_b};
        return;
    }

    my $provider = $self->provider_factory();

    # QESAP deployment

    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    if (defined($instances_export_path) and length($instances_export_path)) {
        copy_ssh_keys();
    }
    if (!get_var("HA_SAP_TERRAFORM_DEPLOYMENT")) {
        qesap_prepare_env(openqa_variables => \%variables);
        $provider->{terraform_env_prepared} = 1;
    }

    my @instances = $provider->create_instances(check_connectivity => 0);
    my @instances_export;

    # Allows to use previous ha-sap-terraform-deployment
    if (!get_var("HA_SAP_TERRAFORM_DEPLOYMENT")) {
        qesap_execute(cmd => 'ansible', verbose => 1, timeout => 3600);
    }

    record_info("Teraform Instances:", Dumper(\@instances));

    foreach my $instance (@instances) {
        $self->{my_instance} = $instance;
        push(@instances_export, $instance);

        my $instance_id = $instance->{'instance_id'};
        # Skip instances without HANA db
        next if ($instance_id !~ m/vmhana/);

        $self->wait_for_sync();

        # Define initial state for both sites
        # Site A is always PROMOTED after deployment
        my $master_node = $self->get_promoted_hostname();

        $run_args->{site_a} = $instance if ($instance_id eq $master_node);
        $run_args->{site_b} = $instance if ($instance_id ne $master_node);

        record_info("Instances:", "Detected HANA instances:
        Site A: $run_args->{site_a}{instance_id}
        Site B: $run_args->{site_b}{instance_id}") if ($instance_id eq $master_node);
    }

    # TODO: DEPLOYMENT SKIP - REMOVE!!!
    # Mostly for dev - for reusing deployed instances, load this file.
    if (defined($instances_export_path) and length($instances_export_path)){
        record_info('Exporting data', Dumper(\@instances_export));
        record_info('Export path', Dumper($instances_export_path));
        store(\@instances_export, $instances_export_path);
    }

    $self->{instances} = $run_args->{instances} = \@instances_export;
    record_info("Deployment OK", )
}


# Only for skip deployment - remove afterwards
sub identify_instances {
    my ($self) = @_;
    my $instances = $self->{instances};
    # Identify Site A (Master) and Site B
    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        my $instance_id = $instance->{'instance_id'};

        # Skip instances without HANA db
        next if ($instance_id !~ m/vmhana/);

        # Define initial state for both sites
        # Site A is always PROMOTED after deployment
        my $master_node = $self->get_promoted_hostname();
        $self->{site_a} = $instance if ($instance_id eq $master_node);
        $self->{site_b} = $instance if ($instance_id ne $master_node);
    }

    if ($self->{site_a}->{instance_id} eq "undef" || $self->{site_b}->{instance_id} eq "undef") {
        die("Failed to identify Hana nodes") ;
    }

    record_info("Instances:", "Detected HANA instances:
        Site A: $self->{site_a}->{instance_id}
        Site B: $self->{site_b}->{instance_id}");

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