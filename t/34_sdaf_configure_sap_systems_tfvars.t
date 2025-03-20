use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Data::Dumper;
use testapi;
use sles4sap::sap_deployment_automation_framework::configure_sap_systems_tfvars;

sub set_openqa_settings {
    my %settings = (
        SAP_SID => 'ABC',
        SDAF_ENV_CODE => 'LAB',
        PUBLIC_CLOUD_REGION => 'swedencentral',
        SDAF_BOM_NAME => 'CaffeineAddiction',
        SDAF_FENCING_MECHANISM => 'sbd',
        PUBLIC_CLOUD_IMAGE_ID => 'suse:sles-sap-15-sp5:gen2:latest'
    );
    set_var($_, $settings{$_}) foreach keys(%settings);
}

sub undef_variables {
    my @openqa_variables = qw(
      SAP_SID
      SDAF_DEPLOYMENT_SCENARIO
      SDAF_ENV_CODE
      PUBLIC_CLOUD_REGION
      SDAF_BOM_NAME
      PUBLIC_CLOUD_IMAGE_ID
      SDAF_FENCING_MECHANISM
    );
    set_var($_, undef) foreach @openqa_variables;
}

subtest '[create_sap_systems_tfvars] Test mandatory arguments' => sub {
    set_openqa_settings;
    dies_ok { create_sap_systems_tfvars(); } 'Croak with missing mandatory arguments';
    undef_variables;
};

subtest '[create_sap_systems_tfvars] ENSA2 cluster settings' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_sap_systems_tfvars', no_auto => 1);
    my $tfvars_data;
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(generate_resource_group_name => sub { return 'NoSleepSquad'; });
    $ms_sdaf->redefine(write_tfvars_file => sub { $tfvars_data = $_[1]; return 'lungo'; });
    $ms_sdaf->redefine(upload_logs => sub { return; });

    set_openqa_settings;
    set_var('SDAF_DEPLOYMENT_SCENARIO', 'db_install,db_ha,nw_pas,nw_ensa');
    create_sap_systems_tfvars(workload_vnet_code => 'SAP05');
    is $tfvars_data->{database_tier}{database_high_availability}, 'true', 'DB ha setup must be enabled';
    is $tfvars_data->{database_tier}{database_server_count}, '1', 'DB count must be 1';
    is $tfvars_data->{application_servers}{application_server_count}, '"1"', 'PAS must be deployed';
    is $tfvars_data->{sap_central_services}{scs_server_count}, '1', 'ASCS deployment must be enabled';
    ok(defined($tfvars_data->{cluster_settings}{database_cluster_type}), 'DB cluster type cannot be empty');
    ok(defined($tfvars_data->{cluster_settings}{scs_cluster_type}), 'SCS cluster type cannot be empty');

    undef_variables;
};

subtest '[create_sap_systems_tfvars] Simple HanaSR cluster settings' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_sap_systems_tfvars', no_auto => 1);
    my $tfvars_data;
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(generate_resource_group_name => sub { return 'NoSleepSquad'; });
    $ms_sdaf->redefine(write_tfvars_file => sub { $tfvars_data = $_[1]; return 'lungo'; });
    $ms_sdaf->redefine(upload_logs => sub { return; });

    set_openqa_settings;
    set_var('SDAF_DEPLOYMENT_SCENARIO', 'db_install,db_ha');
    create_sap_systems_tfvars(workload_vnet_code => 'SAP05');
    is $tfvars_data->{database_tier}{database_high_availability}, 'true', 'DB ha setup must be enabled';
    is $tfvars_data->{database_tier}{database_server_count}, '1', 'DB count must be 1';
    is $tfvars_data->{application_servers}{application_server_count}, '"0"', 'PAS deployment is disabled';
    is $tfvars_data->{sap_central_services}{scs_server_count}, '0', 'ASCS deployment is disabled';
    ok(defined($tfvars_data->{cluster_settings}{database_cluster_type}), 'DB cluster type cannot be empty');

    undef_variables;
};

done_testing;

