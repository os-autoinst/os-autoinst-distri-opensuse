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

    dies_ok { create_workload_tfvars(network_data => undef, workload_vnet_code => 'caracolillo'); }
    'Croak with missing mandatory argument "network_data"';
    dies_ok { create_workload_tfvars(network_data => 'peaberry', workload_vnet_code => undef); }
    'Croak with missing mandatory argument "workload_vnet_code"';

    set_var('SDAF_FENCING_MECHANISM', undef);
};

subtest '[write_tfvars_file] Mandatory args' => sub {

    dies_ok { write_tfvars_file(tfvars_file => undef, tfvars_data => 'arabica'); }
    'Croak with missing mandatory argument "tfvars_file"';
    dies_ok { write_tfvars_file(tfvars_file => 'coffea', tfvars_data => undef); }
    'Croak with missing mandatory argument "tfvars_data"';
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

    ok grep(/### FILE HEADER/, split("\n", $tfvars_file)), 'First line contains file header';
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

