use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_deployment_automation_framework::configure_workload_tfvars;

subtest '[create_workload_tfvars] Test exceptions' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_workload_tfvars', no_auto => 1);
    $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
    $ms_sdaf->redefine(compile_tfvars_section => sub { return 'macchiato'; });
    $ms_sdaf->redefine(find_deployment_id => sub { return 'lungo'; });
    set_var('SDAF_FENCING_MECHANISM', 'msi');
    my %arguments = (environment => 'LAB',
        location => 'swedencentral',
        job_id => '42',
        resource_group => 'Coffea',
        network_data => 'peaberry',
        workload_vnet_code => 'caracolillo'
    );

    for my $arg (keys(%arguments)) {
        my $original = $arguments{$arg};
        $arguments{$arg} = undef;
        $ms_sdaf->redefine(find_deployment_id => sub { return undef; }) if $arg eq 'job_id';
        dies_ok { create_workload_tfvars(%arguments); } "Croak with missing mandatory argument '$arg'";
        $ms_sdaf->redefine(find_deployment_id => sub { return 'lungo'; });
        $arguments{$arg} = $original;
    }
    set_var('SDAF_FENCING_MECHANISM', undef);
};

# subtest '[env_definitions]' => sub {
#     my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_workload_tfvars', no_auto => 1);
#     my $tfvars_file;
#     $ms_sdaf->redefine(get_os_variable => sub { return 'espresso'; });
#     $ms_sdaf->redefine(compile_tfvars_section => sub { return 'espresso'; });
#     $ms_sdaf->redefine(find_deployment_id => sub { return 'lungo'; });
#     $ms_sdaf->redefine(upload_logs => sub { return 'macchiato'; });
#     $ms_sdaf->redefine(write_sut_file => sub { $tfvars_file = $_[1]; return; });
#     set_var('SDAF_FENCING_MECHANISM', 'msi');
#     my %network_data = (
#         network_address_space => '192.168.1.0/26',
#         db_subnet_address_prefix => '192.168.1.0/28',
#         web_subnet_address_prefix => '192.168.1.56/29',
#         admin_subnet_address_prefix => '192.168.1.48/29',
#         iscsi_subnet_address_prefix => '192.168.1.32/28',
#         app_subnet_address_prefix => '192.168.1.16/28'
#     );
#     my %arguments = (environment => 'LAB',
#         location => 'swedencentral',
#         job_id => '42',
#         workload_vnet_code => 'jelly_bean',
#         resource_group => 'Mr.Bean',
#         network_data => \%network_data);
#
#     create_workload_tfvars(%arguments);
#     note("\nTfvars file:\n$tfvars_file");
#     set_var('SDAF_FENCING_MECHANISM', undef);
# };

subtest '[write_tfvars_file] Mandatory args' => sub {

    my %arguments = (tfvars_file => 'coffea', tfvars_data => 'arabica');

    for my $argument ('tfvars_data', 'tfvars_file') {
        my $original = $argument;
        $arguments{$argument} = undef;
        dies_ok { write_tfvars_file(%arguments); } "Croak with missing mandatory argument '$argument'";
        $arguments{$argument} = $original;
    }
};

subtest '[write_tfvars_file] Mandatory args' => sub {
    my %tfvars_data = (is => 'HASHREF');

    dies_ok { write_tfvars_file(tfvars_file => 'coffea', tfvars_data => 'NOT HASHREF') } 'Argument "tfvars_data" must be a HASHREF';
    dies_ok { write_tfvars_file(tfvars_file => 'coffea', tfvars_data => \%tfvars_data, section_order => 'NOT ARRAYREF') }
    'Argument "section_order" must be an ARRAYREF';
};

subtest '[write_tfvars_file]' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_workload_tfvars', no_auto => 1);
    my $tfvars_file;
    $ms_sdaf->redefine(write_sut_file => sub { $tfvars_file = $_[1]; return; });
    my %mock_data = (
        file_header => '### FILE HEADER',
        coffea_plant => {header => '## PLANTS',
            peaberry => 'caracolillo',
            arabica_coffee => 'coffea_arabica'},
        processing => {header => '## PROCESS',
            roasting => 'Saying mean things to the bean'
        });
    set_var('SDAF_FENCING_MECHANISM', 'msi');
    write_tfvars_file(tfvars_data => \%mock_data, tfvars_file => '/config.tfvars');
    note("\nTfvars file:\n$tfvars_file\n\n");

    ok grep(//, split("\n", $tfvars_file)), 'First line contains file header';
    ok grep(/peaberry = caracolillo/, split("\n", $tfvars_file)), 'Correct parameter syntax';
    ok grep(/[PLANTS,PROCESS]/, split("\n", $tfvars_file)), 'File contains section headers';
    ok grep(/[peaberry,arabica_coffee,roasting]/, split("\n", $tfvars_file)), 'File contains all parameters';
    set_var('SDAF_FENCING_MECHANISM', undef);
};

subtest '[write_tfvars_file] Ordered sections' => sub {
    my $ms_sdaf = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::configure_workload_tfvars', no_auto => 1);
    my $sections;
    $ms_sdaf->redefine(compile_tfvars_section => sub { $sections .= "->$_[0]->{header}"; return 'coffee'; });
    $ms_sdaf->redefine(write_sut_file => sub { return; });
    my %mock_data = (
        file_header => '### FILE HEADER',
        drinking => {header => 'DRINK', var => 'iable'},
        picking => {header => 'PICK', var => 'iable'},
        roasting => {header => 'ROAST', var => 'iable'},
        processing => {header => 'PROCESS', var => 'iable'});
    my @section_order = qw(picking processing roasting drinking);
    set_var('SDAF_FENCING_MECHANISM', 'msi');
    write_tfvars_file(tfvars_data => \%mock_data, tfvars_file => '/config.tfvars', section_order => \@section_order);
    is($sections, "->PICK->PROCESS->ROAST->DRINK", 'Section must be written in correct order');
    set_var('SDAF_FENCING_MECHANISM', undef);
};

done_testing;

