use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_deployment_automation_framework::configure_sap_systems_tfvars;

subtest '[create_sap_systems_tfvars] Test exceptions' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_sap_systems_tfvars', no_auto => 1);
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(write_sut_file => sub { return 'lungo'; });
    my %arguments = (environment => 'LAB',
        location => 'swedencentral',
        workload_vnet_code => 'jelly_bean'
    );

    for my $arg (keys(%arguments)) {
        my $original = $arguments{$arg};
        $arguments{$arg} = undef;
        dies_ok { create_sap_systems_tfvars(%arguments); } "Croak with missing mandatory argument '$arg'";
        $arguments{$arg} = $original;
    }
};

subtest '[env_definitions]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_sap_systems_tfvars', no_auto => 1);
    my $tfvars_file;
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(upload_logs => sub { return 'macchiato'; });
    $ms_sdaf->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $ms_sdaf->redefine(write_sut_file => sub { $tfvars_file = $_[1]; return; });

    my %arguments = (
        environment => 'LAB',
        location => 'swedencentral',
        workload_vnet_code => 'jelly_bean',
        high_availability => 'true',
        av_zones => 'true',
        resource_group => 'true',
        sdaf_deployment_scenario => 'db_install,db_ha,nw_pas,nw_aas,nw_ensa',
        sap_sid => 'ABC',
        bom_name => 'asdf',
        os_image => 'suse:sles-sap-15-sp5:gen2:latest'
    );

    create_sap_systems_tfvars(%arguments);
    note("\nTfvars file:\n$tfvars_file");
};

done_testing;

