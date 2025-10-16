use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sap_deployment_automation_framework::naming_conventions;

subtest '[homedir]' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    $mock_lib->redefine(script_output => sub { return '/home/sweet/home' });
    is homedir(), '/home/sweet/home', 'Return path';
};

subtest '[deployment_dir]' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    my @calls;
    $mock_lib->redefine(get_var => sub { return '/tmp' });
    $mock_lib->redefine(find_deployment_id => sub { return '42' });
    $mock_lib->redefine(assert_script_run => sub { push(@calls, $_[0]); return });

    is deployment_dir(), '/tmp/Azure_SAP_Automated_Deployment_42', 'Return deployment path';
    ok(!@calls, "Call without creating deployment dir");
    deployment_dir(create => 1);
    note("\n  CMD: " . join("\n  -->  ", @calls));
    ok(grep(/mkdir -p/, @calls), 'Check for "mkdir" command');
    ok(grep(/\/tmp\/Azure_SAP_Automated_Deployment_42/, @calls), 'Create correct directory');
};

subtest '[log_dir]' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    my @calls;
    $mock_lib->redefine(find_deployment_id => sub { return '0079' });
    $mock_lib->redefine(deployment_dir => sub { return '/narnia' });
    $mock_lib->redefine(assert_script_run => sub { push(@calls, $_[0]); return });

    is log_dir(), '/narnia/openqa_logs', 'Return log path';
    ok(!@calls, "Call without creating log dir");
    log_dir(create => 1);
    note("\n  CMD: " . join("\n  -->  ", @calls));
    ok(grep(/mkdir -p/, @calls), 'Check for "mkdir" command');
    ok(grep(/\/narnia\/openqa_logs/, @calls), 'Create correct directory');
};

subtest '[sdaf_scripts_dir]' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    $mock_lib->redefine(deployment_dir => sub { return '/narnia' });
    is sdaf_scripts_dir(), '/narnia/sap-automation/deploy/scripts', 'Append scripts path to deployment root';
};

subtest '[env_variable_file]' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    $mock_lib->redefine(deployment_dir => sub { return '/narnia' });
    is env_variable_file(), '/narnia/sdaf_variables', 'Append variables filename to deployment root path';
};

subtest '[get_tfvars_path] Test passing scenarios' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    my %arguments = (
        sap_sid => 'QAS',
        vnet_code => 'SAP04',
        sdaf_region_code => 'SECE',
        env_code => 'LAB'
    );
    my %expected_results = (
        workload_zone => '/narnia/LAB-SECE-SAP04-INFRASTRUCTURE-0079.tfvars',
        sap_system => '/narnia/LAB-SECE-SAP04-QAS-0079.tfvars',
        library => '/narnia/LAB-SECE-SAP_LIBRARY-0079.tfvars',
        deployer => '/narnia/LAB-SECE-SAP04-INFRASTRUCTURE-0079.tfvars'
    );

    $mock_lib->redefine(get_sdaf_config_path => sub { return '/narnia'; });
    $mock_lib->redefine(find_deployment_id => sub { return '0079'; });

    foreach (keys(%expected_results)) {
        is get_tfvars_path(%arguments, deployment_type => $_), $expected_results{$_},
          "Pass with corrct tfvars path generated for $_: $expected_results{$_}";
    }
};


subtest '[generate_resource_group_name]' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    $mock_lib->redefine(find_deployment_id => sub { return '0079'; });
    my @expected_failures = ('something_funky', 'workload', 'zone', 'sut', 'lib', 'deploy');
    my %expected_pass = (
        workload_zone => 'SDAF-OpenQA-workload_zone-0079',
        sap_system => 'SDAF-OpenQA-sap_system-0079',
        deployer => 'SDAF-OpenQA-deployer-0079',
        library => 'SDAF-OpenQA-library-0079'
    );

    for my $value (@expected_failures) {
        dies_ok { generate_resource_group_name(deployment_type => $value); } "Fail with unsupported 'SDAF_DEPLOYMENT_TYPE' value: $value";
    }

    for my $type (keys %expected_pass) {
        my $rg = generate_resource_group_name(deployment_type => $type);
        is $rg, $expected_pass{$type}, "Pass with '$type' and resource group '$rg";
    }
};

subtest '[convert_region_to_long] Test conversion' => sub {
    is convert_region_to_long('SECE'), 'swedencentral', 'Convert abbreviation "SECE" to "swedencentral"';
    is convert_region_to_long('WUS2'), 'westus2', 'Convert abbreviation "WUS2" to "westus2"';
    is convert_region_to_long('WEEU'), 'westeurope', 'Convert abbreviation "WEEU" to "westeurope"';
};

subtest '[convert_region_to_long] Test invalid input' => sub {
    my @invalid_abbreviations = qw(aabc ASDF WUS5 WEEUU WWEEU WEEU.);
    dies_ok { convert_region_to_long() } 'Croak with missing mandatory argument';
    dies_ok { convert_region_to_long($_) } "Croak with invalid region abbreviation: $_" foreach @invalid_abbreviations;
};

subtest '[convert_region_to_short] Test conversion' => sub {
    is convert_region_to_short('swedencentral'), 'SECE', 'Convert full region name "swedencentral" to "SECE"';
    is convert_region_to_short('westus2'), 'WUS2', 'Convert full region name "westus2" to "WUS2"';
    is convert_region_to_short('westeurope'), 'WEEU', 'Convert full region name "westeurope" to "WEEU"';
};

subtest '[convert_region_to_short] Test invalid input' => sub {
    my @invalid_region_names = qw(sweden central estus5 . estus);
    dies_ok { convert_region_to_short() } 'Croak with missing mandatory argument';
    dies_ok { convert_region_to_short($_) } "Croak with invalid region name: $_" foreach @invalid_region_names;
};

subtest '[get_workload_vnet_code] ' => sub {
    my $mock_lib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::naming_conventions', no_auto => 1);
    dies_ok { get_workload_vnet_code() } 'Die with with no job id found';

    $mock_lib->redefine(find_deployment_id => sub { return '0079'; });
    is get_workload_vnet_code(), '0079', 'Return correct VNET code with default values';
    is get_workload_vnet_code(job_id => '0087'), '0087', 'Return correct VNET code defined by named argument';
};

subtest '[get_tfvars_path] Test passing scenarios' => sub {
    is get_sdaf_inventory_path(sap_sid => 'ZETA', config_root_path => '/Project/Zeta'),
      '/Project/Zeta/ZETA_hosts.yaml', 'Return correct inventory path.';
    dies_ok { get_sdaf_inventory_path(sap_sid => 'ZETA') } 'Fail with missing config root path argument';
    dies_ok { get_sdaf_inventory_path(config_root_path => '/Project/Zeta') } 'Fail with missing SAP sid argument';
};

subtest '[get_sut_sshkey_path]' => sub {
    is get_sut_sshkey_path(config_root_path => '/Project/Zeta'), '/Project/Zeta/sshkey', 'Return correct ssh key path.';
    dies_ok { get_sut_sshkey_path() } 'Fail with missing config root path argument';
};

subtest '[get_sizing_filename]' => sub {
    set_var('SDAF_DEPLOYMENT_SCENARIO', 'db,nw');
    is get_sizing_filename(), 'custom_sizes_default.json', 'Return correct default file';

    set_var('SDAF_DEPLOYMENT_SCENARIO', 'db,nw,ensa');
    is get_sizing_filename(), 'custom_sizes_S4HANA.json', 'Return filename for ENSA2 scenario';
};

subtest '[get_ibsm_peering_name]' => sub {
    is get_ibsm_peering_name(source_vnet => 'source', target_vnet => 'target'), 'SDAF-source-target', 'Check naming composition';
};


done_testing;
